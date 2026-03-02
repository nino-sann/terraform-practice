## リポジトリ名
terraform-practice
## ブランチ名
work
### コミットハッシュ
8c600c672baf4e292a34099421f520d5cbd09b02
## パス
### terraform
- main.tf
- outputs.tf
- terraform.tf
- test.tftest.hcl
- variables.tf
### GitHub Actions
- .github/workflows/terraform-cicd.yml
- .github/workflows/ansible.yml
### Ansible
- ansible/inventory/group_vars/all.yml
- ansible/playbooks/playbook.yml
- ansible/templates/application.properties.j2
- ansible/templates/springapp.service.j2
- ansible/ansible.cfg
## 再現手順
- terraform init
- terraform plan 
- terraform apply -auto-approve
- ansible-playbook playbooks/playbook.yml -vv \
    --extra-vars "rds_endpoint=*** \
                  db_user=*** \
                  db_password=*** \
                  db_name=***"
## Secrets名
- secrets.KEY_PAIR_NAME
- secrets.CIDRIP_FROM_INTERNET
- secrets.RDS_MASTER_USER_NAME
- secrets.RDS_MASTER_USER_PASSWORD
- secrets.MY_EMAIL_ADDRESS
- secrets.RDS_ENDPOINT
- secrets.RDS_DB_NAME
- secrets.AWS_ROLE_ARN
## EC2のSGに「0.0.0.0/0」が含まれているかを確認
- 確認コマンド
  aws ec2 describe-security-groups \
  --group-ids sg-06143680bfedac494 \
  --filters Name=ip-permission.cidr,Values='0.0.0.0/0' \
  --query "SecurityGroups[].IpPermissions[?contains(IpRanges[].CidrIp, '0.0.0.0/0')]"
- 確認結果
　[]
## ALB の属性
- 確認コマンド
  aws elbv2 describe-load-balancers --names aws-study-alb
- 確認結果
  "Scheme": "internet-facing"
## ターゲットグループのポート
- 確認コマンド
  aws elbv2 describe-target-groups
- 確認結果
  "Port": 8080
## ターゲットグループのヘルスチェックパス
- 確認コマンド
  aws elbv2 describe-target-groups
- 確認結果
  "HealthCheckPath": "/"
## playbook
---
- name: Setup and Run Spring Boot Application
  hosts: web_servers
  gather_facts: false

  vars:
    repo_url: https://github.com/koujienami/aws-study.git
    app_dir: "/home/ec2-user/aws-study"

  tasks:
    # 1. JavaとGitとMySQL(MariaDB)をインストール
    - name: Install Java21 Git MySQL
      ansible.builtin.dnf:
        name: 
         - java-21-amazon-corretto-devel.x86_64
         - git
         - mariadb105 # mysqlコマンドがこれに含まれる
        state: present
      become: true
      become_user: root # sudo権限で実施
    
    - name: ec2_user group
      block: 
        # 2. リポジトリをダウンロード
        - name: Clone the repoitory
          ansible.builtin.git:
           repo: "{{ repo_url }}"
           dest: "{{ app_dir }}"
           force: true
          when: not ansible_check_mode #ドライラン時はタスクをスキップする
    
        # 3. 実行権限の付与
        - name: Grant execute permission to gradlew
          ansible.builtin.file :
            path: "{{ app_dir }}/gradlew"
            mode: '0755'
          when: not ansible_check_mode #ドライラン時はタスクをスキップする
    
        # 4. テンプレートを使って設定ファイルを上書き生成する
        - name: Deploy application.properties from template
          ansible.builtin.template:
            src: ../templates/application.properties.j2
            dest: "{{ app_dir }}/src/main/resources/application.properties"
            mode: '0644'
          no_log: true # 実行ログにパスワード等を表示しない
          when: not ansible_check_mode #ドライラン時はタスクをスキップする

        # テーブルを空にする
        - name: Clean up database table before import
          ansible.builtin.shell: >
             mysql -h {{ rds_endpoint }} -u {{ db_user }} -p{{ db_password }} {{ db_name }}
             -e "TRUNCATE TABLE student;"
          when: not ansible_check_mode
          ignore_errors: true # 初回実行時など、テーブルがない場合のエラーを無視する

        # 5. データベースに情報を書き込む
        - name: Import SQL to RDS
          ansible.builtin.shell: >
            mysql -h {{ rds_endpoint }} -u {{ db_user }} -p{{ db_password }} {{ db_name }}
            < {{ app_dir }}/src/main/resources/create.sql
          when: not ansible_check_mode #ドライラン時はタスクをスキップする

        # 6. Spring Bootを使う準備
        - name: Build application with Gradle
          ansible.builtin.command: ./gradlew build -x test
          args:
            chdir: "{{ app_dir }}"
          changed_when: false # buildするだけで特に何も変わらないので
          when: not ansible_check_mode #ドライラン時はタスクをスキップする
    
        - name: Copy WAR to a fixed name
          ansible.builtin.shell: |
            cp {{ app_dir }}/build/libs/demo-0.0.1-SNAPSHOT.war {{ app_dir }}/app.war
          when: not ansible_check_mode #ドライラン時はタスクをスキップする
      become: true
      become_user: ec2-user

    # 7. serviceファイルの配置
    - name: Deploy Systemd service file
      ansible.builtin.template:
        src: ../templates/springapp.service.j2
        dest: /etc/systemd/system/springapp.service # 要確認
        mode: '0644'
      notify: Reload systemd # ファイルが変わったらdaemon-reloadを呼ぶ
      become: true
      become_user: root # sudo権限で実施
    
    # 8. Spring Bootを起動して有効化する
    - name: Start and Enable Spring Boot service
      ansible.builtin.systemd_service:
        name: springapp
        state: restarted # 常に最新のビルドで再起動
        enabled: true     # OS起動時の自動起動を有効化
      become: true
      become_user: root # sudo権限で実施
      when: not ansible_check_mode #ドライラン時はタスクをスキップする

  handlers:
    - name: Reload systemd
      ansible.builtin.systemd_service:
        daemon_reload: true # serviceファイルの変更を読み取る
      become: true
      become_user: root # sudo権限で実施  
## 実行ログ
PLAY [Setup and Run Spring Boot Application] ***********************************
TASK [Check initial execution user] ********************************************
task path: /home/runner/work/terraform-practice/terraform-practice/ansible/playbooks/playbook.yml:12
changed: [i-076c36398b05e7350] => {"ansible_facts": {"discovered_interpreter_python": "/usr/bin/python3.9"}, "changed": true, "cmd": ["whoami"], "delta": "0:00:00.003725", "end": "2026-03-02 12:45:35.924540", "msg": "", "rc": 0, "start": "2026-03-02 12:45:35.920815", "stderr": "", "stderr_lines": [], "stdout": "ssm-user", "stdout_lines": ["ssm-user"]}
TASK [Show initial execution user] *********************************************
task path: /home/runner/work/terraform-practice/terraform-practice/ansible/playbooks/playbook.yml:16
ok: [i-076c36398b05e7350] => {
    "msg": "このPlaybookの基本実行ユーザーは ssm-user です"
}
TASK [Install Java21 Git MySQL] ************************************************
task path: /home/runner/work/terraform-practice/terraform-practice/ansible/playbooks/playbook.yml:21
ok: [i-076c36398b05e7350] => {"ansible_facts": {"pkg_mgr": "dnf"}, "changed": false, "msg": "Nothing to do", "rc": 0, "results": []}
TASK [Check initial execution user] ********************************************
task path: /home/runner/work/terraform-practice/terraform-practice/ansible/playbooks/playbook.yml:32
changed: [i-076c36398b05e7350] => {"changed": true, "cmd": ["whoami"], "delta": "0:00:00.003699", "end": "2026-03-02 12:45:49.311344", "msg": "", "rc": 0, "start": "2026-03-02 12:45:49.307645", "stderr": "", "stderr_lines": [], "stdout": "***", "stdout_lines": ["***"]}
TASK [Show initial execution user] *********************************************
task path: /home/runner/work/terraform-practice/terraform-practice/ansible/playbooks/playbook.yml:38
ok: [i-076c36398b05e7350] => {
    "msg": "現在のタスク実行ユーザーは *** です"
}
TASK [Clone the repoitory] *****************************************************
task path: /home/runner/work/terraform-practice/terraform-practice/ansible/playbooks/playbook.yml:45
changed: [i-076c36398b05e7350] => {"after": "9fa191448f7da81b585aac1b4c83983f9c2a9621", "before": "9fa191448f7da81b585aac1b4c83983f9c2a9621", "changed": true, "msg": "Local modifications exist in the destination: /home/ec2-user/aws-study", "remote_url_changed": false}
TASK [Grant execute permission to gradlew] *************************************
task path: /home/runner/work/terraform-practice/terraform-practice/ansible/playbooks/playbook.yml:53
changed: [i-076c36398b05e7350] => {"changed": true, "gid": 1000, "group": "ec2-user", "mode": "0755", "owner": "ec2-user", "path": "/home/ec2-user/aws-study/gradlew", "secontext": "system_u:object_r:user_home_t:s0", "size": 8762, "state": "file", "uid": 1000}
TASK [Deploy application.properties from template] *****************************
task path: /home/runner/work/terraform-practice/terraform-practice/ansible/playbooks/playbook.yml:60
changed: [i-076c36398b05e7350] => {"censored": "the output has been hidden due to the fact that 'no_log: true' was specified for this result", "changed": true}
TASK [Clean up database table before import] ***********************************
task path: /home/runner/work/terraform-practice/terraform-practice/ansible/playbooks/playbook.yml:69
changed: [i-076c36398b05e7350] => {"changed": true, "cmd": "mysql -h *** -u *** -p*** *** -e \"TRUNCATE TABLE student;\"\n", "delta": "0:00:00.170261", "end": "2026-03-02 12:46:14.246664", "msg": "", "rc": 0, "start": "2026-03-02 12:46:14.076403", "stderr": "", "stderr_lines": [], "stdout": "", "stdout_lines": []}
TASK [Import SQL to RDS] *******************************************************
task path: /home/runner/work/terraform-practice/terraform-practice/ansible/playbooks/playbook.yml:77
changed: [i-076c36398b05e7350] => {"changed": true, "cmd": "mysql -h *** -u *** -p*** *** < /home/ec2-user/aws-study/src/main/resources/create.sql\n", "delta": "0:00:00.026094", "end": "2026-03-02 12:46:19.491765", "msg": "", "rc": 0, "start": "2026-03-02 12:46:19.465671", "stderr": "", "stderr_lines": [], "stdout": "", "stdout_lines": []}
TASK [Build application with Gradle] *******************************************
task path: /home/runner/work/terraform-practice/terraform-practice/ansible/playbooks/playbook.yml:84
ok: [i-076c36398b05e7350] => {"changed": false, "cmd": ["./gradlew", "build", "-x", "test"], "delta": "0:00:17.613492", "end": "2026-03-02 12:46:42.362849", "msg": "", "rc": 0, "start": "2026-03-02 12:46:24.749357", "stderr": "", "stderr_lines": [], "stdout": "Starting a Gradle Daemon (subsequent builds will be faster)\n> Task :compileJava UP-TO-DATE\n> Task :processResources UP-TO-DATE\n> Task :classes UP-TO-DATE\n> Task :resolveMainClassName UP-TO-DATE\n> Task :bootWar UP-TO-DATE\n> Task :war UP-TO-DATE\n> Task :assemble UP-TO-DATE\n> Task :check\n> Task :build\n\nBUILD SUCCESSFUL in 17s\n5 actionable tasks: 5 up-to-date", "stdout_lines": ["Starting a Gradle Daemon (subsequent builds will be faster)", "> Task :compileJava UP-TO-DATE", "> Task :processResources UP-TO-DATE", "> Task :classes UP-TO-DATE", "> Task :resolveMainClassName UP-TO-DATE", "> Task :bootWar UP-TO-DATE", "> Task :war UP-TO-DATE", "> Task :assemble UP-TO-DATE", "> Task :check", "> Task :build", "", "BUILD SUCCESSFUL in 17s", "5 actionable
TASK [Copy WAR to a fixed name] ************************************************
task path: /home/runner/work/terraform-practice/terraform-practice/ansible/playbooks/playbook.yml:91
changed: [i-076c36398b05e7350] => {"changed": true, "cmd": "cp /home/ec2-user/aws-study/build/libs/demo-0.0.1-SNAPSHOT.war /home/ec2-user/aws-study/app.war\n", "delta": "0:00:00.010107", "end": "2026-03-02 12:46:48.147042", "msg": "", "rc": 0, "start": "2026-03-02 12:46:48.136935", "stderr": "", "stderr_lines": [], "stdout": "", "stdout_lines": []}
TASK [Check initial execution user] ********************************************
task path: /home/runner/work/terraform-practice/terraform-practice/ansible/playbooks/playbook.yml:99
changed: [i-076c36398b05e7350] => {"changed": true, "cmd": ["whoami"], "delta": "0:00:00.005344", "end": "2026-03-02 12:46:53.433237", "msg": "", "rc": 0, "start": "2026-03-02 12:46:53.427893", "stderr": "", "stderr_lines": [], "stdout": "ec2-user", "stdout_lines": ["ec2-user"]}
TASK [Show initial execution user] *********************************************
task path: /home/runner/work/terraform-practice/terraform-practice/ansible/playbooks/playbook.yml:105
ok: [i-076c36398b05e7350] => {
    "msg": "現在のタスク実行ユーザーは ec2-user です"
}
TASK [Deploy Systemd service file] *********************************************
task path: /home/runner/work/terraform-practice/terraform-practice/ansible/playbooks/playbook.yml:110
ok: [i-076c36398b05e7350] => {"changed": false, "checksum": "6fd30a8c9f8aabb587f09a49092122d2ee9dae8a", "dest": "/etc/systemd/system/springapp.service", "gid": 0, "group": "***", "mode": "0644", "owner": "***", "path": "/etc/systemd/system/springapp.service", "secontext": "system_u:object_r:systemd_unit_file_t:s0", "size": 384, "state": "file", "uid": 0}
TASK [Start and Enable Spring Boot service] ************************************
task path: /home/runner/work/terraform-practice/terraform-practice/ansible/playbooks/playbook.yml:120
changed: [i-076c36398b05e7350] => {"changed": true, "enabled": true, "name": "springapp", "state": "started", "status": {"AccessSELinuxContext": "system_u:object_r:systemd_unit_file_t:s0", "ActiveEnterTimestamp": "Mon 2026-03-02 10:34:13 UTC", "ActiveEnterTimestampMonotonic": "4786849", "ActiveExitTimestampMonotonic": "0", "ActiveState": "active", "After": "system.slice basic.target -.mount systemd-journald.socket network.target sysinit.target", "AllowIsolate": "no", "AssertResult": "yes", "AssertTimestamp": "Mon 2026-03-02 10:34:13 UTC", "AssertTimestampMonotonic": "4784887", "Before": "shutdown.target multi-user.target", "BlockIOAccounting": "no", "BlockIOWeight": "[not set]", "CPUAccounting": "yes", "CPUAffinityFromNUMA": "no", "CPUQuotaPerSecUSec": "infinity", "CPUQuotaPeriodUSec": "infinity", "CPUSchedulingPolicy": "0", "CPUSchedulingPriority": "0", "CPUSchedulingResetOnFork": "no", "CPUShares": "[not set]", "CPUUsageNSec": "29279978000", "CPUWeight": "[not set]", "CacheDirectoryMode": "0755", "CanFreeze
TASK [Check initial execution user] ********************************************
task path: /home/runner/work/terraform-practice/terraform-practice/ansible/playbooks/playbook.yml:130
changed: [i-076c36398b05e7350] => {"changed": true, "cmd": ["whoami"], "delta": "0:00:00.009519", "end": "2026-03-02 12:47:12.382227", "msg": "", "rc": 0, "start": "2026-03-02 12:47:12.372708", "stderr": "", "stderr_lines": [], "stdout": "***", "stdout_lines": ["***"]}
TASK [Show initial execution user] *********************************************
task path: /home/runner/work/terraform-practice/terraform-practice/ansible/playbooks/playbook.yml:136
ok: [i-076c36398b05e7350] => {
    "msg": "現在のタスク実行ユーザーは *** です"
}
PLAY RECAP *********************************************************************
i-076c36398b05e7350        : ok=18   changed=11   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
