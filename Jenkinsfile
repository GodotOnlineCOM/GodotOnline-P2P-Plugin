pipeline {
    agent {
        docker {
            image 'godot-build-image'
            args '-v /root/.local:/root/.local -v /root/.config:/root/.config -v /root/.cache:/root/.cache'
        }
    }
    stages {
        stage('Build') {
            steps {
                sh '/usr/local/bin/Godot_v4.4-stable_linux.x86_64 --headless --export-release Linux'
            }
        }
    }
}
