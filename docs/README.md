## 1. プロジェクト概要
### 受講生情報表示アプリ 自動デプロイパイプライン
GitHubへのpushをトリガーに、インフラ構築からアプリのデプロイまでを完全自動化したCI/CDパイプラインです。  
Terraform・GitHub Actions・Ansibleを組み合わせ、再現性の高い環境構築を実現しています。

## 2. システム構成
### 2.1 構成図
![システム構成図](aws-terraform-ansible.drawio.svg)

### 2.2 VPC/ネットワーク構成
| リソース | CIDR | AZ | 役割 |
|:---:|:---:|:---:|---|
| VPC | 10.0.0.0/16 | - | 全リソースを収容 |
| PublicSubnet1 | 10.0.1.0/24 | ap-northeast-1a | EC2配置・ALB |
| PublicSubnet2 | 10.0.3.0/24 | ap-northeast-1c | AL冗長化用 |
| PrivateSubnet1 | 10.0.2.0/24 | ap-northeast-1a | RDS配置 |
| PrivateSubnet2 | 10.0.4.0/24 | ap-northeast-1c | RDSサブネットグループ用 |

## 3. CI/CDパイプラインフロー
![パイプラインフロー図](CICD-Pipelines.png)

pushからデプロイ完了まで自動化をしています。(apply実行時のみ人の手による承認が必要)

## 4. 使用技術
| カテゴリ | 技術 | バージョン |
|:---:|:---:|:---:|
| CI/CD | GitHub Actions | - |
| IaC | Terraform | 1.14.8 |
| デプロイ | Ansible |  |
| アプリケーション | Spring Boot |  |
| クラウド | AWS | - |
| OS | Amazon Linux 2023 | - |
| データベース | MySQL | 8.0.43 |

## 5. AWSリソース一覧
| リソース | サービス | 用途 |
|:---:|:---:|---|
| VPC | Amazon VPC | ネットワーク全体の分離 |
| EC2 | t3.micro | アプリケーションサーバー |
| RDS | db.t4g.micro | データベース |
| ALB | Application Load Balancer | HTTPリクエストのルーティング |
| WAFv2 | AWS WAF | ALBへの不正アクセスをブロック |
| CloudWatch | Alarm | CPU使用率の監視・アラート |
| SNS | Topic/Subscription | メール通知 |
| CloudWatch Logs | Log Group | WAFログの収集・保管 |

## 6. ディレクトリ構成
```text
.
├── .github
│   └── workflows
│       ├── ansible.yml                   # GitHub Actionsワークフロー定義(Ansible実行)
│       └── terraform-cicd.yml            # GitHub Actionsワークフロー定義(Terraform実行)
├── .gitignore                            # gitにpushしないファイルを定義
├── ansible
│   ├── ansible.cfg                       # 動作設定
│   ├── inventory
│   │   └── group_vars
│   │       └── all.yml                   # 接続・環境設定
│   ├── playbooks
│   │   └── playbook.yml                  # デプロイ手順の定義
│   └── templates
│       ├── application.properties.j2     # アプリケーション設定ファイル
│       └── springapp.service.j2          # Systemd用のテンプレート
├── main.tf                               # リソース定義
├── outputs.tf                            # アウトプット定義(EC2のIDなど)
├── terraform.tf                          # Terraform本体の設定
├── terraform.tfvars                      # 変数の値
├── test.tftest.hcl                       # テストコード
└── variables.tf                          # 変数定義
```

## 7. デプロイ手順
### 7.1 前提条件
- AWSアカウントおよびIAMユーザー(必要な権限を付与済みであること)
- ap-northeast-1リージョンにEC2キーペアが作成済み
- SNSサブスクリプションを受け取れるメールアドレス
- GitHubリポジトリへのアクセス

### 7.2 GitHub Secretsの設定
リポジトリのSettings → Secrets and variables → Actionsに以下を登録します。

| Secret名 | 内容 |
|:---:|---|
| AWS_ROLE_ARN | OIDC認証を使ってAWS連携をするためのロール |
| CIDRIP_FROM_INTERNET | EC2にSSH接続を許可する自分のIPアドレス(x.x.x.x/32) |
| KEY_PAIR_NAME | EC2にSSH接続する際に使用する既存のキーペア名 |
| MY_EMAIL_ADDRESS| CloudWatchアラーム通知の送信先 |
| RDS_DB_NAME | データベースの名前 |
| RDS_ENDPOINT | RDSの接続先 |
| RDS_MASTER_USER_NAME | RDSマスターユーザー名 |
| RDS_MASTER_USER_PASSWORD | RDSマスターユーザーのパスワード |

### 7.3 デプロイの実行
mainブランチにpushするだけで、GitHub Actionsが自動的にデプロイを実行します。(apply時には人の手による承認が必要)

```zsh
git add .
git commit -m ""
git push origin ブランチ名
```

### 7.4 環境の削除
AWSリソースは使用後に削除してください。  
削除しないと料金が発生し続けます。

```zsh
terraform destroy
```

## 8. 工夫した点
### Terraformのfor_eachと三項演算子による柔軟なリソース管理
- 4つのサブネットを作成する際にfor_eachを活用し、1つのリソースブロックで複数リソースを定義できるように工夫しました

mian.tf
```hcl
resource "aws_subnet" "public_private" {
  vpc_id = aws_vpc.main.id

  for_each = var.terraform_subnets

  availability_zone       = each.value.zone
  cidr_block              = each.value.cidr
  map_public_ip_on_launch = each.value.launch

  tags = {
    Name = each.value.name
  }
}
```
variables.tf
```hcl
variable "terraform_subnets" {
  type = map(object({
    cidr      = string
    zone      = string
    launch    = bool # 文字列 "true" ではなく 真偽値 bool
    name      = string
    is_public = bool # 文字列 "true" ではなく 真偽値 bool
  }))

  default = {
    public-1a = {
      cidr      = "10.0.1.0/24"
      zone      = "ap-northeast-1a"
      launch    = true
      name      = "terraform-study-public-subnet1"
      is_public = true
    }
    public-1c = {
      cidr      = "10.0.3.0/24"
      zone      = "ap-northeast-1c"
      launch    = true
      name      = "terraform-study-public-subnet2"
      is_public = true
    }
    private-1a = {
      cidr      = "10.0.2.0/24"
      zone      = "ap-northeast-1a"
      launch    = false
      name      = "terraform-study-private-subnet1"
      is_public = false
    }
    private-1c = {
      cidr      = "10.0.4.0/24"
      zone      = "ap-northeast-1c"
      launch    = false
      name      = "terraform-study-private-subnet2"
      is_public = false
    }
  }
}
```
- ルートテーブルとサブネットを関連付ける際にもfor_eachを活用し、サブネットと同じ数だけループを回すようにしました
- 三項演算子を用いて、条件によって関連付けるルートテーブルを切り替えるようにし、コードの重複を排除しました

main.tf
```hcl
resource "aws_route_table_association" "public_private" {
  for_each = var.terraform_subnets # サブネットと同じ数だけループを回す

  # each.key は "public-1a" などが入る
  subnet_id = aws_subnet.public_private[each.key].id # 作成したサブネットの ID を取得

  # 三項演算子でルートテーブルを切り替える
  # 条件式 ? true_value : false_value
  route_table_id = each.value.is_public ? aws_route_table.public.id : aws_route_table.private.id
}
```
 
### セキュリティ面の配慮
- EC2へのSSH接続は、特定のIPアドレス(/32)からのみ許可し、0.0.0.0/0は禁止しました
- 各種パスワードなど機密情報はGitHub Secretsで管理し、コードには一切含めないようにしました
- Environment機能を利用し、apply実行時は人の手による承認を必要としました
- GitHub ActionsのAWS認証について、OIDC認証を採用しセキュリティを強化しました
- AnsibleとAWSの接続について、SSM接続を採用しセキュリティを強化しました

## 9. 苦労した点・学び
### AnsibleとAWSのSSM接続設定
AnsibleからEC2への接続に、SSHではなくAWS Systems Manager(SSM)を使う構成を試みましたが、接続がうまく確立できずに詰まりました。  
原因を調査した結果、group_vars/all.yamlの配置ミスのため、Ansibleが接続に必要な変数を見つけられないことが原因でした。  
group_vars/all.yamlを下記のように配置し直した結果、無事にSSM接続が確立できました。
- 変更前
```text
```

- 変更後
```text
.
├── ansible
│   ├── ansible.cfg
│   ├── inventory
│   │   └── group_vars
│   │       └── all.yml
│   └── playbooks
│       └── playbook.yml
```

### IaC
cloudformationは繰り返しコードを書かなければいけなかったが、terraformは関数を使用できるので、スッキリした

## 10. 今後の改善点
- HTTPSの対応：ACMを用いたSSL証明書の取得とALBのHTTS化(ポート443)








