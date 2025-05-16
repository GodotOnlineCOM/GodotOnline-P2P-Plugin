pipeline {
    agent {
        docker {
            image 'godot-build-image'
        }
    }
    stages {
        stage('Checkout') {
            steps {
                git 'https://github.com/GodotOnlineCOM/GodotOnline-P2P-Plugin.git'
            }
        }
        stage('Build') {
            steps {
                sh '/usr/local/bin/Godot_v4.4.1-stable_linux.x86_64 --headless --export-release Linux/X11'
            }
        }
    }
}
