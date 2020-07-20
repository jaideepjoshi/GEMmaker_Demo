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

## Prepping GEMmaker's reference genome
The GEMmaker [repository](https://github.com/SystemsGenetics/GEMmaker) and [documentation](https://gemmaker.readthedocs.io/en/latest/) should be followed along these specific parameters. GEMmaker requires fastq input files which will be compiled into a gene expression matrix (GEM). In order to do this, we must download the fastq files from their source and install a reference genome by which GEMmaker can align the transcription data.

First, we must prepare our genome data for GEMmaker to use. This data can be directly downloaded from [Ensembl](https://useast.ensembl.org/Homo_sapiens/Info/Index). We will use the entire DNA primary assembly from the GRCh38 build of the human genome. We need:
* A FASTA file containing the full genomic sequence in FASTA format (either pseudomolecules or scaffolds)
* A GTF file containing the gene models

In order to index our reference genome we need access to the hisat2 binaries within a container on our k8s cluster. We will create a k8s deployment which we can then exec into to access a bash terminal with hisat2 software tools and access to our pvc. Create a new directory for docker yaml files `/home/user/dockerized/hisat2-dockerized.yaml`. The `claimName` parameter should be set to the valid pvc configured for your namespace

```
kubectl apply -f /home/<user>/dockerized/hisat2-deployment.yaml
kubectl get pods
```
Once you see a pod with `gm-k8s-*` and a status of `ready`, we're cooking with peanut oil. We will now exec into this k8s pod to use hisat2 to index our reference genome.
```
kubectl exec -ti <pod name> -- /bin/bash
```
Once you have access to a bash terminal, access your workspace by `cd /workspace/<user>`. We will now begin prepping our GEMmaker inputs by downloading the ensembl fasta and gtf files and indexing our genome. In the course of the following commands, we download and unpack the fasta and gtf files, index the genome with the name `Homo_Sapiens`, and create this index directory.
```
mkdir /workspace/<user>/references | cd /workspace/<user>/references
wget ftp://ftp.ensembl.org/pub/release-100/fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz
gunzip Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz
wget ftp://ftp.ensembl.org/pub/release-100/gtf/homo_sapiens/Homo_sapiens.GRCh38.100.chr.gtf.gz
gunzip Homo_sapiens.GRCh38.100.chr.gtf.gz
hisat2-build -f Homo_sapiens.GRCh38.dna.primary_assembly.fa Homo_Sapiens
mkdir /workspace/<user>/references/Homo_Sapiens
mv /workspace/<user>/references/*ht2 /workspace/<user>/references/Homo_Sapiens
```
This reference genome is prepped and ready to be used for our GEMmaker run. 

## Downloading input fastq data
We will use [SRA-kidney](https://www.ncbi.nlm.nih.gov/sra?linkname=bioproject_sra_all&from_uid=359795) data for the construction of our GEM. This data consists of 36 paired-end fastq files of non-tumor kidney tissues from 36 patients undergoing nephrectomy for exploring the metabolic mechanism of sorafenib and identifying the major transcriptional regulation factors in sorafenib metabolism in kidney. Due to the total size of this data (0.16Tb), we will use a more efficient method of data transfer than generic scp transfer. The SRAtoolkit allows for containerized data transfer within HPC clusters, which is why we set this to `true` in the values.yaml file for dtp. The data transfer pod makes this transfer easy. 
```
cd /workspace/<user>/dtp
./start
./interact
```
This starts the data transfer pod, which we will essentially exec into. Once a bash terminal has started, select `1` to enter the dtp-base pod. We will not have access to the SRAtoolkit executables, however we can configure our environment to make the data transfer easy.
```
cd /workspace/<user>
mkdir /workspace/<user>/misc | cd /workspace/<user>/misc
apt-get update
apt-get install nano
nano install.sh
```
Copy the contents of the install.sh script in this repo into this file within your pod. Be sure to change the <user> parameter to your username. This file will execute the fastq-dump command from the batch of SRAtoolkit executables and download all 36 pairs of fastq files onto your storage claim. In order to do this, we need a list of SRA accession IDs. This is copied in this repo as `SraAccList.txt`, however you should download it for yourself and copy the results. It can be downloaded locally [here](https://www.ncbi.nlm.nih.gov/sra?linkname=bioproject_sra_all&from_uid=359795) by clicking the 'send to' link and going to 'file', then downloading the Accession List format. Create a new file and copy the results of this query into it. 
```
mkdir /workspace/<user>/input
nano /workspace/<user>/input/SraAccList.txt
```

Now exit the dtp-base pod by simply running `exit`. We will re-enter the dtp-sra-toolkit to download our fastq inputs. This can be done using the background feature of dtp, however we will do it interactively to follow the output and send it to an output file
```
cd /workspace/<user>/misc
chmod +x install.sh
./install.sh SraAccList.txt > dtp_out.txt
```
In the end, you should have 72 fastq files from 36 paired-end samples. The `references` directory should now be moved into the `input` directory. There should also be a `samples2skip.txt` file that should be empty, so just put a space in the file. In the end, this should be your directory structure...
```
-input/
  -references/
      -Homo_Sapiens/
        -*.ht2
      -*.fa
      -*.gtf
  -samples2skip.txt
  -*.fastq
  -SraAccList.txt
```


  
  
  
  
  
  
  
