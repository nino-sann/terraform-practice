## リポジトリ名
terraform-practice
## ブランチ名
sub2
### コミットハッシュ
794f203324c7b9f56794ca030785004984b1cfe7
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
## ポート22の許可先
aws ec2 describe-security-groups \
    --filters Name=ip-permission.from-port,Values=22 \
    --query "SecurityGroups[*].{ID:GroupId, Name:GroupName, IPs:IpPermissions[?ToPort==\`22\`].IpRanges[*].CidrIp}" \
DescribeSecurityGroups 
- ID:sg-06143680bfedac494 
- Name:EC2-SG
- IPs: *** . *** . *** .** /32
## ALB の属性
-  "Scheme": "internet-facing"
## ターゲットグループのポート
- "Port": 8080
## ターゲットグループのヘルスチェックパス
- "HealthCheckPath": "/"
## ansible/playbooks/playbook.yml の 記述
- 管理者権限が必要なtaskごとにbecome_user: root としています
  