# k8s-openstack-kubeadm-bootstrap

Steps to reproduce a cluster with this repository:
1. Go to infra-terraform, and run terraform init, then terraform apply
2. Wait for machines to get created. Terraform output will include some useful info like floating ip values
3. Go to your domain DNS zone and assign these ip addresses to k8s.dev.superuser.kz (cluster load balancer ip) and gitlab.superuser.kz (gitlab machine ip)
4. Wait for some time for dns changes to propagate
5. Go to ansible dir and run ansible-playbook k8s-cluster-deploy.yml -v
6. As soon as playbook is finished, you will get .kubeconfig on you local laptop where you ran ansible and can start managing cluster from you cli

## Things to improve:
1. Currently this k8s cluster is missing a proper ingress solution as openstack octavia controller was not mature enough half a year ago when this solution was in active development. If that's still the case, I suggest using MetalLB.
2. This cluster cannot provision domain certificates automatically due to lack of ingress controller.
