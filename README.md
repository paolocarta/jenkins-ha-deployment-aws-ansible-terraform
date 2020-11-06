
<h1>Setup Requirements</h1><br />

```
1. Terraform binary => 0.12.x 
3. Ansible (install via pip) 
4. AWS CLI (install via pip) 
5. jq (install via package manager) - OPTIONAL 
```

<h2>Notes and Instructions</h2><br />

*For Terraform Part*
```
The regional AWS providers are defined in providers.tf
Terraform configuration and backend is defined in backend.tf.


If you want to read and understand the deployment in sequence. Read through templates in the following order:
1. network_setup.tf
2. instances.tf --> local-exec provisioners in this templates kick-off Ansible playbooks in ansible_templates/
3. alb_acm.tf
4. dns.tf
```
*S3 Backend*
```
This project requires an S3 backend for storing Terraform state file, therefore in the terraform block in the backend.tf file you'll need to plug in the an actual bucket name before you can run "terraform init".
Please also note that the "terraform" block does not allow usage of variables so values HAVE to be hardcoded.
```
Sample command for bucket creation via CLI:

```
aws s3api create-bucket --bucket myawesomebucketthatmayormaynotexistalready
```

<h2>Supplementary files </h2> <br />

```
1. ansible.cfg #A modified Ansible default config file with SSH host key checking and warnings disabled
2. aws_get_cp_hostedzone #An AWS CLI command for fetching your hosted zone for DNS part of this project
3. variables.tf #Defines variables and default values for them for the TF templates
4. outputs.tf #Defines the outputs presented at successful completion of execution of TF apply.
```

<h2>Ansible playbooks</h2><br />

```
1. cred-privkey.j2 #Jinja template for creating Jenkins credentials via Jenkins API call(populates private key)
2. install_jenkins.yaml #Playbook for Jenkins Master
3. install_worker.yaml #Playbook for Jenkins Worker
4. node.j2 #Jinja templates for registering worker node with Jenkins Master via Jenkins CLI(populates IP)
5. jenkins_auth #Provides the file with preset credentials for our Jenkins Master
```
