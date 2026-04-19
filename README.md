## 1. プロジェクト概要
### 受講生情報表示アプリ 自動デプロイパイプライン
GitHubへのpushをトリガーに、インフラ構築からアプリのデプロイまでを完全自動化したCI/CDパイプラインです。

Terraform・GitHub Actions・Ansibleを組み合わせ、再現性の高い環境構築を実現しています。

## 2. システム構成
### 2.1 構成図
![システム構成図](./docs/aws-terraform-ansible.drawio.svg)

### 2.2 VPC/ネットワーク構成
| リソース | CIDR | AZ | 役割 |
|:---:|:---:|:---:|---|
| VPC | 10.0.0.0/16 | - | 全リソースを収容 |
| PublicSubnet1 | 10.0.1.0/24 | ap-northeast-1a | EC2配置・ALB |
| PublicSubnet2 | 10.0.3.0/24 | ap-northeast-1c | AL冗長化用 |
| PrivateSubnet1 | 10.0.2.0/24 | ap-northeast-1a | RDS配置 |
| PrivateSubnet2 | 10.0.4.0/24 | ap-northeast-1c | RDSサブネットグループ用 |

## 3. CI/CDパイプラインフロー
![パイプラインフロー図](./docs/CICD-Pipelines.drawio.svg)

pushから自動デプロイ完了まで完全自動化をしており、人の操作は不要です。

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
|:---:|:---:|:---:|
| CI/CD | GitHub Actions | - |
| IaC | Terraform | 1.14.8 |
| デプロイ | Ansible |  |
| アプリケーション | Spring Boot |  |
| クラウド | AWS | - |
| OS | Amazon Linux 2023 | - |
| データベース | MySQL | 8.0.43 |





