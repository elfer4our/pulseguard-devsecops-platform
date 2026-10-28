pipeline {
    agent any

    environment {
        APP_NAME   = "pulseguard-api"
        IMAGE_TAG  = "${env.GIT_COMMIT ? env.GIT_COMMIT.take(7) : 'local'}"
        REGISTRY   = "registry.nus.edu.sg/devops"
        K8S_NS     = "pulseguard-prod"
    }

    options {
        timeout(time: 15, unit: 'MINUTES')
        disableConcurrentBuilds()
        ansiColor('xterm')
    }

    stages {
        stage('1. Secret & SAST Scan') {
            steps {
                script {
                    echo "Running Gitleaks secret detection and static code analysis..."
                    sh '''
                        docker run --rm -v "${WORKSPACE}:/path" zricethezav/gitleaks:latest detect --source="/path" -v
                    '''
                }
            }
        }

        stage('2. Unit Tests & Dependency Audit (SCA)') {
            steps {
                sh '''
                    python3 -m venv .venv
                    . .venv/bin/activate
                    pip install --upgrade pip
                    pip install -r app/requirements.txt pip-audit
                    pytest app/test_main.py -v
                    pip-audit -r app/requirements.txt
                '''
            }
        }

        stage('3. Build Immutable Container Image') {
            steps {
                sh "docker build -f docker/Dockerfile -t ${REGISTRY}/${APP_NAME}:${IMAGE_TAG} ."
            }
        }

        stage('4. Container Vulnerability Scan (Trivy)') {
            steps {
                sh '''
                    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                        aquasec/trivy:latest image --exit-code 1 --severity CRITICAL \
                        ${REGISTRY}/${APP_NAME}:${IMAGE_TAG}
                '''
            }
        }

        stage('5. Zero-Downtime K8s Deployment & Rollout Check') {
            when {
                branch 'main'
            }
            steps {
                sh """
                    kubectl apply -f k8s/
                    kubectl set image deployment/${APP_NAME} api=${REGISTRY}/${APP_NAME}:${IMAGE_TAG} -n${K8S_NS}
                    kubectl rollout status deployment/${APP_NAME} -n${K8S_NS} --timeout=120s
                """
            }
        }
    }

    post {
        failure {
            echo "Deployment or security gate failed! Executing automatic rollback if on main..."
            script {
                if (env.BRANCH_NAME == 'main') {
                    sh "kubectl rollout undo deployment/${APP_NAME} -n${K8S_NS} || true"
                }
            }
        }
        always {
            cleanWs()
        }
    }
}
