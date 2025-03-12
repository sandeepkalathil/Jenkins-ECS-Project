pipeline {
    agent none
    
    environment {
        DOCKER_IMAGE = 'task-manager'
        DOCKER_TAG = "${BUILD_NUMBER}"
        DOCKER_REGISTRY = 'your-registry.amazonaws.com'
        AWS_REGION = 'eu-north-1'
        ECR_REPOSITORY = 'task-manager'
        NODE_ENV = 'production'
    }
    
    stages {
        stage('Build and Test') {
            agent {
                node {
                    label 'ec2-build-node'
                    customWorkspace '/home/ubuntu/jenkins-agent/workspace'
                }
            }
            
            steps {
                // Clean workspace
                cleanWs()
                
                // Checkout code
                checkout scm
                
                // Build in Docker container
                script {
                    try {
                        docker.image('node:18-alpine').inside('--memory=4g --cpus=2') {
                            sh 'npm ci --production=false'  // Use ci for clean install
                            sh 'npm run test'
                            sh 'npm run lint'
                            sh 'npm run build'
                            
                            // Archive build artifacts
                            sh 'tar -czf dist.tar.gz dist/'
                            archiveArtifacts artifacts: 'dist.tar.gz', fingerprint: true
                        }
                    } catch (Exception e) {
                        currentBuild.result = 'FAILURE'
                        error "Build failed: ${e.message}"
                    }
                }
            }
        }
        
        stage('Build Docker Image') {
            agent {
                node {
                    label 'ec2-build-node'
                    customWorkspace '/home/ubuntu/jenkins-agent/workspace'
                }
            }
            
            steps {
                script {
                    try {
                        def customImage = docker.build("${DOCKER_REGISTRY}/${ECR_REPOSITORY}:${DOCKER_TAG}", '--no-cache .')
                        
                        // Test the built image
                        customImage.inside {
                            sh 'nginx -t'  // Test nginx configuration
                        }
                    } catch (Exception e) {
                        currentBuild.result = 'FAILURE'
                        error "Docker build failed: ${e.message}"
                    }
                }
            }
        }
        
        stage('Trivy Scan') {
            agent {
                node {
                    label 'ec2-build-node'
                    customWorkspace '/home/ubuntu/jenkins-agent/workspace'
                }
            }
            
            steps {
                script {
                    try {
                        sh """
                            docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                            aquasec/trivy image \
                            --cache-dir /tmp/trivy \
                            --timeout 10m \
                            --exit-code 1 \
                            --severity HIGH,CRITICAL \
                            --no-progress \
                            ${DOCKER_REGISTRY}/${ECR_REPOSITORY}:${DOCKER_TAG}
                        """
                    } catch (Exception e) {
                        currentBuild.result = 'FAILURE'
                        error "Security scan failed: ${e.message}"
                    }
                }
            }
        }
        
        stage('Push to ECR') {
            agent {
                node {
                    label 'ec2-build-node'
                    customWorkspace '/home/ubuntu/jenkins-agent/workspace'
                }
            }
            
            steps {
                script {
                    try {
                        // Login to ECR with retry
                        retry(3) {
                            sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${DOCKER_REGISTRY}"
                        }
                        
                        // Push image with retry
                        retry(3) {
                            sh "docker push ${DOCKER_REGISTRY}/${ECR_REPOSITORY}:${DOCKER_TAG}"
                        }
                        
                        // Tag as latest if on main branch
                        if (env.BRANCH_NAME == 'main') {
                            sh """
                                docker tag ${DOCKER_REGISTRY}/${ECR_REPOSITORY}:${DOCKER_TAG} ${DOCKER_REGISTRY}/${ECR_REPOSITORY}:latest
                                docker push ${DOCKER_REGISTRY}/${ECR_REPOSITORY}:latest
                            """
                        }
                    } catch (Exception e) {
                        currentBuild.result = 'FAILURE'
                        error "Failed to push to ECR: ${e.message}"
                    }
                }
            }
        }
        
        stage('Deploy to ECS') {
            agent {
                node {
                    label 'ec2-build-node'
                    customWorkspace '/home/ubuntu/jenkins-agent/workspace'
                }
            }
            
            steps {
                script {
                    try {
                        // Update task definition with new image
                        sh """
                            aws ecs describe-task-definition \
                                --task-definition task-manager \
                                --region ${AWS_REGION} \
                                --query 'taskDefinition' \
                                --output json > task-def.json
                            
                            # Update image in task definition
                            jq '.containerDefinitions[0].image = "${DOCKER_REGISTRY}/${ECR_REPOSITORY}:${DOCKER_TAG}"' task-def.json > new-task-def.json
                            
                            # Register new task definition
                            aws ecs register-task-definition \
                                --region ${AWS_REGION} \
                                --cli-input-json file://new-task-def.json
                        """
                        
                        // Update service with new task definition
                        sh """
                            aws ecs update-service \
                                --cluster task-manager-cluster \
                                --service task-manager-service \
                                --task-definition task-manager \
                                --force-new-deployment \
                                --region ${AWS_REGION}
                        """
                        
                        // Wait for service to be stable
                        sh """
                            aws ecs wait services-stable \
                                --cluster task-manager-cluster \
                                --services task-manager-service \
                                --region ${AWS_REGION}
                        """
                    } catch (Exception e) {
                        currentBuild.result = 'FAILURE'
                        error "Deployment failed: ${e.message}"
                    }
                }
            }
        }
        
        stage('Health Check') {
            agent {
                node {
                    label 'ec2-build-node'
                    customWorkspace '/home/ubuntu/jenkins-agent/workspace'
                }
            }
            
            steps {
                script {
                    try {
                        // Get the ALB DNS name
                        def albDns = sh(
                            script: """
                                aws elbv2 describe-load-balancers \
                                    --region ${AWS_REGION} \
                                    --names task-manager-alb \
                                    --query 'LoadBalancers[0].DNSName' \
                                    --output text
                            """,
                            returnStdout: true
                        ).trim()
                        
                        // Perform health check
                        sh """
                            for i in {1..12}; do
                                if curl -sf http://${albDns}/; then
                                    echo "Health check passed"
                                    exit 0
                                fi
                                echo "Waiting for service to be healthy..."
                                sleep 10
                            done
                            echo "Health check failed"
                            exit 1
                        """
                    } catch (Exception e) {
                        currentBuild.result = 'FAILURE'
                        error "Health check failed: ${e.message}"
                    }
                }
            }
        }
    }
    
    post {
        success {
            node('ec2-build-node') {
                script {
                    // Notify on success
                    sh "echo 'Deployment successful'"
                }
            }
        }
        failure {
            node('ec2-build-node') {
                script {
                    // Notify on failure
                    sh "echo 'Deployment failed'"
                }
            }
        }
        always {
            node('ec2-build-node') {
                script {
                    // Clean up Docker images
                    sh """
                        docker rmi ${DOCKER_REGISTRY}/${ECR_REPOSITORY}:${DOCKER_TAG} || true
                        docker rmi ${DOCKER_REGISTRY}/${ECR_REPOSITORY}:latest || true
                        docker system prune -f || true
                    """
                    
                    // Clean workspace
                    cleanWs()
                }
            }
        }
    }
}