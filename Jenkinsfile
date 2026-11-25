pipeline {
    agent any

    parameters {
        choice(name: 'DEPLOY_STRATEGY', choices: [
            'rolling-update', 'blue-green', 'canary', 'shadow', 'ab-testing'
        ], description: 'Progressive delivery strategy to apply after the quality gate')
        string(name: 'APP_VERSION', defaultValue: '1.0.0', description: 'Semantic version from the Git tag')
        booleanParam(name: 'PUSH_IMAGE', defaultValue: true, description: 'Push the release image to Docker Hub')
        booleanParam(name: 'DEPLOY_TO_K8S', defaultValue: true, description: 'Deploy and smoke-test on the cluster')
        booleanParam(name: 'RUN_SONAR', defaultValue: true, description: 'Run the SonarQube analysis and quality gate')
    }

    triggers {
        pollSCM('H/5 * * * *')
    }

    options {
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '15', artifactNumToKeepStr: '15'))
        disableConcurrentBuilds()
        timeout(time: 35, unit: 'MINUTES')
        skipDefaultCheckout(true)
    }

    environment {
        IMAGE_NAME = 'aceest-fitness'
        APP_VERSION = "${params.APP_VERSION}"
        DEPLOY_STRATEGY = "${params.DEPLOY_STRATEGY}"
        GIT_SHA = ''
        DEPLOYED = 'false'
    }

    stages {
        stage('Checkout') {
            steps {
                script {
                    checkout scm
                    env.GIT_SHA = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                }
                echo "Building ${env.IMAGE_NAME}:${env.APP_VERSION} @ ${env.GIT_SHA}"
            }
        }

        stage('Prepare') {
            steps {
                sh '''
                    set -eu
                    rm -rf .ci-venv reports
                    mkdir -p reports
                    python3 -m venv .ci-venv
                    .ci-venv/bin/pip install --upgrade pip
                    .ci-venv/bin/pip install -r requirements-dev.txt
                    .ci-venv/bin/pip check
                    .ci-venv/bin/python -m compileall -q ACEest_Fitness.py app.py config.py aceest
                '''
            }
        }

        stage('Lint') {
            steps {
                sh '.ci-venv/bin/python -m flake8 ACEest_Fitness.py app.py config.py aceest tests --count'
            }
        }

        stage('Unit Tests in Container') {
            steps {
                sh '''
                    set -eu
                    docker build --target test -t "${IMAGE_NAME}:test-${BUILD_NUMBER}" .
                    cid=$(docker create "${IMAGE_NAME}:test-${BUILD_NUMBER}" \
                        python -m pytest \
                            --junitxml=reports/junit.xml \
                            --cov=aceest \
                            --cov-report=term-missing \
                            --cov-report=xml:reports/coverage.xml \
                            --cov-fail-under=90)
                    docker start -a "${cid}"
                    docker cp "${cid}:/app/reports/." reports/
                    docker rm "${cid}" >/dev/null
                    python3 scripts/normalize-coverage.py reports/coverage.xml
                '''
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'reports/junit.xml'
                }
            }
        }

        stage('SonarQube Quality Gate') {
            when {
                expression { return params.RUN_SONAR }
            }
            steps {
                withCredentials([string(
                    credentialsId: 'sonar-token',
                    variable: 'SONAR_TOKEN'
                )]) {
                    sh '''
                        set -eu
                        docker run --rm --network host \
                            -v "${WORKSPACE}:/usr/src" -w /usr/src \
                            -e SONAR_HOST_URL=http://localhost:9000 \
                            -e SONAR_TOKEN \
                            sonarsource/sonar-scanner-cli \
                            -Dsonar.projectVersion="${APP_VERSION}" \
                            -Dsonar.python.coverage.reportPaths=reports/coverage.xml

                        for i in $(seq 1 60); do
                            status=$(curl -fsS -u "${SONAR_TOKEN}:" \
                                "http://localhost:9000/api/qualitygates/project_status?projectKey=aceest-fitness-cicd" \
                                | python3 -c 'import json,sys; print(json.load(sys.stdin)["projectStatus"]["status"])')
                            if [ "${status}" = "OK" ]; then
                                echo "Quality gate: PASS"
                                exit 0
                            fi
                            if [ "${status}" = "ERROR" ]; then
                                echo "Quality gate: FAILED"
                                exit 1
                            fi
                            sleep 3
                        done
                        echo "Timed out waiting for quality gate"
                        exit 1
                    '''
                }
            }
        }

        stage('Build Release Image') {
            steps {
                sh '''
                    set -eu
                    docker build \
                        --build-arg APP_VERSION="${APP_VERSION}" \
                        --build-arg DEPLOY_STRATEGY="${DEPLOY_STRATEGY}" \
                        --build-arg RELEASE_COLOR="${RELEASE_COLOR:-blue}" \
                        --build-arg GIT_SHA="${GIT_SHA}" \
                        --build-arg BUILD_NUMBER="${BUILD_NUMBER}" \
                        -t "${IMAGE_NAME}:${APP_VERSION}" \
                        -t "${IMAGE_NAME}:${DEPLOY_STRATEGY}" \
                        -t "${IMAGE_NAME}:latest" .
                '''
            }
        }

        stage('Push to Docker Hub') {
            when {
                expression { return params.PUSH_IMAGE }
            }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-credentials',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh '''
                        set -eu
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker tag "${IMAGE_NAME}:${APP_VERSION}" "${DOCKER_USER}/${IMAGE_NAME}:${APP_VERSION}"
                        docker tag "${IMAGE_NAME}:${APP_VERSION}" "${DOCKER_USER}/${IMAGE_NAME}:latest"
                        docker push "${DOCKER_USER}/${IMAGE_NAME}:${APP_VERSION}"
                        docker push "${DOCKER_USER}/${IMAGE_NAME}:latest"
                        docker logout
                    '''
                }
            }
        }

        stage('Deploy and Smoke Test') {
            when {
                expression { return params.DEPLOY_TO_K8S }
            }
            steps {
                script {
                    env.DEPLOYED = 'true'
                }
                sh '''
                    set -eu
                    IMAGE_REF="${IMAGE_NAME}:${APP_VERSION}"
                    if command -v minikube >/dev/null 2>&1 && minikube status >/dev/null 2>&1; then
                        minikube image load "${IMAGE_REF}"
                    fi
                    scripts/deploy.sh "${DEPLOY_STRATEGY}" "${IMAGE_REF}"
                    scripts/smoke-test.sh
                '''
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'reports/**', allowEmptyArchive: true
        }
        failure {
            script {
                if (env.DEPLOYED == 'true') {
                    sh "scripts/rollback.sh ${params.DEPLOY_STRATEGY} || true"
                }
            }
        }
        success {
            echo "Released ${env.IMAGE_NAME}:${env.APP_VERSION} using ${env.DEPLOY_STRATEGY}"
        }
    }
}
