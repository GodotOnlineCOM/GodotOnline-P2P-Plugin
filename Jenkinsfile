pipeline {
    agent any
    stages {
        stage('Checkout') {
            steps {
                git 'https://github.com/GodotOnlineCOM/GodotOnline-P2P-Plugin.git'
            }
        }
        stage('Build') {
            steps {
                sh 'docker run --rm godot-build-image /usr/local/bin/Godot_v4.4.1-stable_linux.x86_64 --headless --export Linux/X11'
            }
        }
    }
}
