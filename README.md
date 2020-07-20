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
Finally, we need to edit dtp to access our newly mounted pvc...
```
nano /home/<user>/dtp/helm/values.yaml
```
* Set SRAtoolkit enabled to `true`
* Set ExistingPVC to `true` and provide the name of your established pvc

## Prepping GEMmaker prerequisites
The GEMmaker [repository](https://github.com/SystemsGenetics/GEMmaker) and [documentation](https://gemmaker.readthedocs.io/en/latest/) should be followed along these specific parameters. GEMmaker requires fastq input files which will be compiled into a gene expression matrix (GEM). In order to do this, we must download the fastq files from their source and install a reference genome by which GEMmaker can align the transcription data.

First, we must prepare our genome data for GEMmaker to use. This data can be directly downloaded from [Ensembl](https://useast.ensembl.org/Homo_sapiens/Info/Index). We need:
* A [FASTA](ftp://ftp.ensembl.org/pub/release-100/fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz) file containing the full genomic sequence in FASTA format (either pseudomolecules or scaffolds)
** We will use the entire DNA primary assembly from the GRCh38 build of the human genome
* A [GTF](ftp://ftp.ensembl.org/pub/release-100/gtf/homo_sapiens/Homo_sapiens.GRCh38.100.chr.gtf.gz) file containing the gene models.


