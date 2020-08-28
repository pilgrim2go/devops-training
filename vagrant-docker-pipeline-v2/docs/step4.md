# Phase 2 - Prepare to Production


### Provision EC2 Instances

Create `provisioners/aws.yml` with following content

```
---
- hosts: localhost
  connection: local
  gather_facts: false

  vars:
    aws_profile: default
    aws_region: us-west-2 # Oregon
    aws_ec2_ami: ami-0a634ae95e11c6f91 # Ubuntu 1804
    id: "web-app"
    sec_group: "{{ id }}-sec"
    vpc_id: vpc-0d42a7ad13ccd83a9 # existing VPC

    instances:
      - name: nc.dev
        group: "dev"
      - name: nc.registry
        group: "registry"
      - name: nc.prod
        group: "prod"


  tasks:
    - name: Create security group
      ec2_group:
        name: "{{ sec_group }}"
        description: "Sec group for app {{ id }}"
        vpc_id: "{{ vpc_id }}"
        region: "{{ aws_region }}"

        rules:
          - proto: tcp
            ports:
              - 22
            cidr_ip: 0.0.0.0/0
            rule_desc: allow all on ssh port
          - proto: tcp
            ports:
              - 4002
            cidr_ip: 0.0.0.0/0
            rule_desc: allow all on ssh port            
          - proto: tcp
            ports:
              - 5000
            cidr_ip: 0.0.0.0/0
            rule_desc: allow all on ssh port            

      register: result_sec_group

    - name: Provision EC2 instances.
      ec2:
        key_name: "{{ item.ssh_key | default('aws-t') }}"
        instance_tags:
          Name: "{{ item.name | default('') }}"
          Application: docker_pipeline_aws
          inventory_group: "{{ item.group | default('') }}"
          inventory_host: "{{ item.name | default('') }}"
        group_id: "{{ result_sec_group.group_id }}"
        instance_type: "{{ item.type | default('t2.micro')}}"
        image: "{{ aws_ec2_ami }}"
        wait: yes
        wait_timeout: 500
        exact_count: 1
        vpc_subnet_id: subnet-07439bd9625a577a9
        assign_public_ip: yes        
        count_tag:
          inventory_host: "{{ item.name | default('') }}"
        profile: "{{ aws_profile }}"
        region: "{{ aws_region }}"
      register: created_instances
      with_items: "{{ instances }}"

- hosts: aws
  gather_facts: false

  tasks:
    - name: Wait for hosts to become available.
      wait_for_connection:

```


and run `ansible-playbook provisioners/aws.yml -vvv`

### Provision EC2 Explain

#### Run Ansible in local mode

```
- hosts: localhost
  connection: local
  gather_facts: false
```  

We can run Ansible against local box that utilize our devbox resource. In this case, Ansible to use AWS credential to create resource


see more https://docs.ansible.com/ansible/latest/user_guide/playbooks_delegation.html#local-playbooks

### Define default variables

```
    aws_profile: default (1)
    aws_region: us-west-2 # Oregon (2)
    aws_ec2_ami: ami-0a634ae95e11c6f91 # Ubuntu 1804 (3)
    id: "web-app" (4)
    sec_group: "{{ id }}-sec" (5)
    vpc_id: vpc-0d42a7ad13ccd83a9 # existing VPC (6)
```    

(1) Ansible to look up default profile in ~/.aws/credentials to get credential to run


(2) Which region
(3) Image ID to create
(4)(5) Security Group ( Ec2 Firewall) attached with instance
(6) A VPC Network


#### Create Security Group

```
    - name: Create security group
      ec2_group:
        name: "{{ sec_group }}"
        description: "Sec group for app {{ id }}"
        vpc_id: "{{ vpc_id }}"
        region: "{{ aws_region }}"

        rules:
          - proto: tcp
            ports:
              - 22
            cidr_ip: 0.0.0.0/0
            rule_desc: allow all on ssh port
          - proto: tcp
            ports:
              - 4002
            cidr_ip: 0.0.0.0/0
            rule_desc: allow all on ssh port            
          - proto: tcp
            ports:
              - 5000
            cidr_ip: 0.0.0.0/0
            rule_desc: allow all on ssh port            

      register: result_sec_group
```

see https://docs.ansible.com/ansible/latest/modules/ec2_group_module.html

### Create Instances

```
    - name: Provision EC2 instances.
      ec2:
        key_name: "{{ item.ssh_key | default('aws-t') }}"
        instance_tags:
          Name: "{{ item.name | default('') }}"
          Application: docker_pipeline_aws
          inventory_group: "{{ item.group | default('') }}"
          inventory_host: "{{ item.name | default('') }}"
        group_id: "{{ result_sec_group.group_id }}"
        instance_type: "{{ item.type | default('t2.micro')}}"
        image: "{{ aws_ec2_ami }}"
        wait: yes
        wait_timeout: 500
        exact_count: 1
        vpc_subnet_id: subnet-07439bd9625a577a9
        assign_public_ip: yes        
        count_tag:
          inventory_host: "{{ item.name | default('') }}"
        profile: "{{ aws_profile }}"
        region: "{{ aws_region }}"
      register: created_instances
      with_items: "{{ instances }}"
```      

see https://docs.ansible.com/ansible/latest/modules/ec2_module.html  


### Define inventory 

Edit inventories/aws/aws_ec2.yml

```
---
plugin: aws_ec2

regions:
  - us-west-2

hostnames:
  - ip-address

keyed_groups:
  - key: tags.inventory_group
    separator: ''
  - key: tags.Application
    separator: ''

```    

#### List hosts to verify inventory is fine
`ansible-playbook -i inventories/aws/ provision.yml --list-hosts`

we can see something like this

```
playbook: provision.yml

  play #1 (all): all    TAGS: []
    pattern: ['all']
    hosts (3):
      52.36.106.126
      54.185.77.22
      34.212.174.199

  play #2 (registry): registry  TAGS: []
    pattern: ['registry']
    hosts (1):
      52.36.106.126

  play #3 (dev): dev    TAGS: []
    pattern: ['dev']
    hosts (1):
      54.185.77.22

  play #4 (prod): prod  TAGS: []
    pattern: ['prod']
    hosts (1):
      34.212.174.199

```

#### Up and Running

Provision
`ansible-playbook --user  ubuntu -i inventories/aws/ provision.yml -vv`      

Notes: 

Don't forget adding your keypair


