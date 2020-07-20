# GEMmaker_Demo
Use case for running the SystemsGenetics/GEMmaker workflow on a kubernetes cluster

## Establishing access to the Rodeo kubernetes cluster
Once permission has been granted to access the TACC cluster, ssh into the cluster.
```
ssh <TACCusername>@kinc01.tacc.utexas.edu
```
This will come with the kubectl binary pre-configured. You will be provided with your own namespace, however there is no mounted storage class. We need to submit a persistent volume claim which will mount our namespace to the storage class of the larger TACC cluster. Place the yaml in `/home/<user>/mount`.

Download the pv-claim.yaml file and use this to submit the storage claim.
```
kubectl apply -f /home/<user>/mount/pv-claim.yaml
kubectl get pvc rodeo-pvc
```
The storage should be bound to the larger volume

## Setting up the environment for GEMmaker
Clone two necessary repos for configuring and running GEMmaker into `/home/<user>`
```
git clone https://github.com/SciDAS/dtp.git
git clone https://github.com/SystemsGenetics/GEMmaker.git
```
Install helm and nextflow which will be necessary into `/home/<user>/bin`
```
wget https://get.helm.sh/helm-v3.3.0-rc.1-linux-amd64.tar.gz
tar -zxvf helm-v3.3.0-rc.1-linux-amd64.tar.gz
mv helm-v3.3.0-rc.1-linux-amd64/helm ..

curl -s https://get.nextflow.io | bash
nextflow run hello
```
