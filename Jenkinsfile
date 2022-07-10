def appList = [
    "adservice",
    "cartservice",
    "checkoutservice",
    "currencyservice",
    "emailservice",
    "frontend",
    "loadgenerator",
    "paymentservice",
    "productcatalogservice",
    "recommendationservice",
    "shippingservice"
]

pipeline {
    agent any
    stages {
        stage('Prepare') {
            steps {
                script {
                    appList.each   {
                        sh "aws ecr describe-repositories --repository-names esagirov-aws-bb/${it} || aws ecr create-repository --repository-name esagirov-aws-bb/${it}"
                    }
                }
            }
            
        }
        stage('Build') {
            steps { 
                script {
                    appList.each {
                        if (it == "cartservice") {
                            appPath = "apps/src/${it}/src"
                        } else {
                            appPath = "apps/src/${it}"
                        }
                        dir("${appPath}") {
                            sh "docker build . -t 589295909756.dkr.ecr.eu-west-1.amazonaws.com/esagirov-aws-bb/${it}:${BUILD_NUMBER}"
                        }
                    }
                }
            }
        }
        stage('Publish') {
            steps { 
                script {
                    appList.each {
                        dir("apps/src/${it}") {
                            sh "aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin 589295909756.dkr.ecr.eu-west-1.amazonaws.com"
                            sh "docker push 589295909756.dkr.ecr.eu-west-1.amazonaws.com/esagirov-aws-bb/${it}:${BUILD_NUMBER}"
                        }
                    }
                }
            }
        }

    }
}