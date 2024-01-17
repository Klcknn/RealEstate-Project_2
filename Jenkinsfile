pipeline {
    agent any
    environment {
        PATH=sh(script:"echo $PATH:/usr/local/bin", returnStdout:true).trim()
        AWS_REGION = "us-east-1"
        AWS_ACCOUNT_ID=sh(script:'export PATH="$PATH:/usr/local/bin" && aws sts get-caller-identity --query Account --output text', returnStdout:true).trim()
        ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        GITHUB_REPO_NAME_MAIN = "jenkins-docker-terraform-ecrec"
        GITHUB_REPO_NAME_FRONTEND = "prettierHome-frontend-dev"
        GITHUB_REPO_NAME_BACKEND  = "prettierHome-backend-dev"
        IMAGE_REPO_NAME_FRONTEND  = "frontend"
        IMAGE_REPO_NAME_BACKEND   = "backend"
        IMAGE_TAG="latest"
    }

    stages {
        stage('Delete Previously Cloned Folder from Github Repo') {
            steps {
                script {
                    def folder_path = "/var/lib/jenkins/workspace/new_pipeline/${GITHUB_REPO_NAME_MAIN}" 
                    sh "rm -rf ${folder_path}"
                    echo "Mevcut clone etmiş olduğumuz '$folder_path' klasörü silindi..."
                }
            }
        } 

        stage("Clone Githup Project Repo") {
            steps {
                script {
                    withCredentials([ 
                        string(credentialsId:"github_user", variable: "Github_User"), 
                        string(credentialsId:"github_token", variable: "Github_Token") 
                    ]){
                        sh "git clone https://$Github_User:$Github_Token@github.com/Klcknn/jenkins-docker-terraform-ecrec.git"
                    }
                }
            }
        } 

        stage('Check ECR Repo Existence') {
            steps {
                script {
                    def ecrRepoExists = sh(script: "aws ecr describe-repositories --repository-names ${IMAGE_REPO_NAME_FRONTEND}", returnStatus: true) == 0
                    def ecrRepoExists_2 = sh(script: "aws ecr describe-repositories --repository-names ${IMAGE_REPO_NAME_FRONTEND}", returnStatus: true) == 0
                    if (ecrRepoExists && ecrRepoExists_2) {
                        sh "aws ecr delete-repository --repository-name ${IMAGE_REPO_NAME_FRONTEND} --force"
                        echo "ECR Repo '${IMAGE_REPO_NAME_FRONTEND}' başarıyla silindi."
                        sh "aws ecr delete-repository --repository-name ${IMAGE_REPO_NAME_BACKEND} --force"
                        echo "ECR Repo '${IMAGE_REPO_NAME_BACKEND}' başarıyla silindi."
                    } 
                }
            }
        }

        stage("Create Two ECR Repo") {
            steps {
                echo "Creating ECR Repo for Frontend"
                sh """
                aws ecr create-repository \
                  --repository-name ${IMAGE_REPO_NAME_FRONTEND} \
                  --image-scanning-configuration scanOnPush=false \
                  --image-tag-mutability MUTABLE \
                  --region ${AWS_REGION}
                aws ecr create-repository \
                  --repository-name ${IMAGE_REPO_NAME_BACKEND} \
                  --image-scanning-configuration scanOnPush=false \
                  --image-tag-mutability MUTABLE \
                  --region ${AWS_REGION}
                """
            }
        }

        stage("Build and Push Frontend Image to ECR Repo") {
            steps {
                script {
                    withCredentials([ 
                        string(credentialsId:"aws_acces_key",  variable: "Aws_Acces_Key"), 
                        string(credentialsId:"aws_secret_key", variable: "Aws_Secret_Key") 
                    ]){   
                        sh """
                            echo "Building and Pushing Frontend Image to ECR Repo"
                            aws configure set aws_access_key_id ${Aws_Acces_Key}
                            aws configure set aws_secret_access_key ${Aws_Secret_Key}
                            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY} 
                            cd ${GITHUB_REPO_NAME_MAIN}/${GITHUB_REPO_NAME_FRONTEND}
                            docker build . -t ${IMAGE_REPO_NAME_FRONTEND}:${IMAGE_TAG}
                            docker tag ${IMAGE_REPO_NAME_FRONTEND}:${IMAGE_TAG} ${ECR_REGISTRY}/${IMAGE_REPO_NAME_FRONTEND}:${IMAGE_TAG}
                            docker push ${ECR_REGISTRY}/${IMAGE_REPO_NAME_FRONTEND}:${IMAGE_TAG}
                        """
                    }
                }
            }
        }      

        stage("Build and Push Backend Image to ECR Repo") {
            steps {
                script {
                    withCredentials([ 
                        string(credentialsId:"aws_acces_key",  variable: "Aws_Acces_Key"), 
                        string(credentialsId:"aws_secret_key", variable: "Aws_Secret_Key") 
                    ]){
                        sh """
                            echo "Building and Pushing Backend Image to ECR Repo"
                            aws configure set aws_access_key_id ${Aws_Acces_Key}
                            aws configure set aws_secret_access_key ${Aws_Secret_Key} 
                            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY} 
                            cd ${GITHUB_REPO_NAME_MAIN}/${GITHUB_REPO_NAME_BACKEND}
                            docker build . -t ${IMAGE_REPO_NAME_BACKEND}:${IMAGE_TAG}
                            docker tag ${IMAGE_REPO_NAME_BACKEND}:${IMAGE_TAG} ${ECR_REGISTRY}/${IMAGE_REPO_NAME_BACKEND}:${IMAGE_TAG}
                            docker push ${ECR_REGISTRY}/${IMAGE_REPO_NAME_BACKEND}:${IMAGE_TAG}
                        """
                    }
                }
            }
        }
    }

    post {
        success {
            echo 'Pipeline successfully executed!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}

