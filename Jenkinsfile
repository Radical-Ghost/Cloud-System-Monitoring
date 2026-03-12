pipeline {
    agent any

    environment {
        DOCKER_IMAGE = 'cloud-system-monitor'
        DOCKER_TAG   = "${env.BUILD_NUMBER}"
        OCI_SSH_KEY  = credentials('oci-ssh-key')     // Jenkins SSH private key credential
    }

    stages {
        // ── Stage 1: Pull Code ─────────────────────────────────────
        stage('Pull Code') {
            steps {
                echo '📥 Pulling source code...'
                checkout scm
            }
        }

        // ── Stage 2: Build Docker Image ────────────────────────────
        stage('Build Docker Image') {
            steps {
                echo '🐳 Building Docker image...'
                sh "docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} ."
                sh "docker tag ${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_IMAGE}:latest"
            }
        }

        // ── Stage 3: Trivy Security Scan ───────────────────────────
        stage('Trivy Security Scan') {
            steps {
                echo '🔒 Running Trivy vulnerability scan...'
                sh """
                    trivy image \
                        --severity HIGH,CRITICAL \
                        --exit-code 0 \
                        --format table \
                        ${DOCKER_IMAGE}:${DOCKER_TAG}
                """
                // Save JSON report as build artifact
                sh """
                    trivy image \
                        --severity HIGH,CRITICAL \
                        --format json \
                        --output trivy-report.json \
                        ${DOCKER_IMAGE}:${DOCKER_TAG}
                """
                archiveArtifacts artifacts: 'trivy-report.json', allowEmptyArchive: true
            }
        }

        // ── Stage 4: Terraform Init ────────────────────────────────
        stage('Terraform Init') {
            steps {
                echo '🏗️ Initialising Terraform...'
                dir('terraform') {
                    sh 'terraform init'
                }
            }
        }

        // ── Stage 5: Terraform Apply ───────────────────────────────
        stage('Terraform Apply') {
            steps {
                echo '🚀 Applying Terraform configuration...'
                dir('terraform') {
                    sh 'terraform apply -auto-approve'
                }
            }
        }

        // ── Stage 6: Deploy to OCI Compute Instance ────────────────
        stage('Deploy to OCI') {
            steps {
                echo '📦 Deploying container to OCI compute instance...'
                dir('terraform') {
                    script {
                        def instance_ip = sh(
                            script: "terraform output -raw instance_public_ip",
                            returnStdout: true
                        ).trim()

                        sh """
                            # Save Docker image as tarball
                            docker save ${DOCKER_IMAGE}:latest -o /tmp/cloud-monitor.tar

                            # Copy image to OCI instance
                            scp -o StrictHostKeyChecking=no \
                                -i ${OCI_SSH_KEY} \
                                /tmp/cloud-monitor.tar \
                                opc@${instance_ip}:/tmp/cloud-monitor.tar

                            # SSH and deploy
                            ssh -o StrictHostKeyChecking=no \
                                -i ${OCI_SSH_KEY} \
                                opc@${instance_ip} << 'ENDSSH'

                                # Load Docker image
                                sudo docker load -i /tmp/cloud-monitor.tar

                                # Stop old container if running
                                sudo docker stop cloud-monitor || true
                                sudo docker rm cloud-monitor   || true

                                # Run new container
                                sudo docker run -d \
                                    --name cloud-monitor \
                                    --restart unless-stopped \
                                    -p 5000:5000 \
                                    ${DOCKER_IMAGE}:latest

                                # Cleanup
                                rm -f /tmp/cloud-monitor.tar

                                echo "✅ Container deployed successfully!"
ENDSSH
                        """

                        echo "🌐 Dashboard URL: http://${instance_ip}:5000"
                    }
                }
            }
        }
    }

    post {
        success {
            echo '✅ Pipeline completed successfully!'
        }
        failure {
            echo '❌ Pipeline failed. Check logs for details.'
        }
        always {
            echo '🧹 Cleaning up...'
            sh 'rm -f /tmp/cloud-monitor.tar'
            cleanWs()
        }
    }
}
