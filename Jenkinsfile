pipeline {
    agent any
    environment {
        DOCKER_IMAGE = "godot-build-image"
        PROJECT_PATH = "/app/project.godot"
    }
    stages {
        stage('Checkout') {
            steps {
                git 'https://github.com/GodotOnlineCOM/GodotOnline-P2P-Plugin.git'
            }
        }
        stage('Build & Export') {
            steps {
                sh '''
                docker run --rm \
                -v $(pwd):/app \
                -w /app \
                ${DOCKER_IMAGE} /usr/local/bin/Godot_v4.4-stable_linux.x86_64 --headless --export-release Linux ${PROJECT_PATH}
                '''
            }
        }
    }
}
