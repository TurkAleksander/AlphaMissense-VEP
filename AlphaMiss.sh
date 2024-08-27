#!/bin/bash
#set -euo pipefail
#IFS=$'\n\t'
set +u
set -e

#### LOCAL ####
# 
# LOCALDIR="/home/peterjuv/Documents/CIGM/Epilepsy"
# mkdir -p "$LOCALDIR"
# cd "$LOCALDIR"

#### CONNECT ####

#ashCmgsrv1did
#screen -c _screenrc -DR FMS_burden
#mkdir -p /cmg1scratch/PROJECTS/Familial_MS
cd /cmg1scratch/PROJECTS/Varcopp_test/AlphaMissense_VEP_test

#### VARIABLES ####

## input
#NIN=MS_4042
#NOUT=FMS_burden
#NOUT2=FMS_burden2
DD="/cmg1scratch/PROJECTS/Varcopp_test/AlphaMissense_VEP_test"
#MVCF_IN=$DD/$NIN.vcf.gz
#ll $MVCF_IN -h
BD="/cmg1scratch/PROJECTS/Varcopp_test/AlphaMissense_VEP_test"
#SMPLS=$BD/samples/Study_participants_FMS_and_CTRL.txt
#SMPLS2=$BD/samples/samples_"$NOUT2"_v03_2023-10-18.txt
echo $SMPLS

## outputs for VCF
WD=$BD
# mkdir -p $WD
# chmod a+rwx $WD
# cd $WD

#### VEP: GLOBALS + ANNFIELDS

DIRVEP="/mnt/dbPublic/VEP"
dbNSFPver=4.4a
DIRNSFP=/mnt/dbPublic/dbNSFP${dbNSFPver}
SUBLOF=lofteeGRCh38

#DBNSFP_ANNFIELDS_DEFAULT_VEP="1000Gp3_AC,1000Gp3_EUR_AC,CADD_phred,ESP6500_AA_AC,ESP6500_EA_AC,FATHMM_pred,GERP++_NR,GERP++_RS,Interpro_domain,LRT_pred,MetaSVM_pred,MutationAssessor_pred,MutationTaster_pred,PROVEAN_pred,Polyphen2_HDIV_pred,Polyphen2_HVAR_pred,SIFT_pred,Uniprot_acc,phastCons100way_vertebrate"
#DBNSFP_ANNFIELDS_PRED_VEP="MetaRNN_score,MetaRNN_rankscore,MetaRNN_pred,REVEL_score,REVEL_rankscore,Aloft_prob_Tolerant,Aloft_prob_Recessive,Aloft_prob_Dominant,Aloft_pred,Aloft_Confidence"
#DBNSFP_ANNFIELDS_GNOMAD_VEP="gnomAD_exomes_AC,gnomAD_exomes_nhomalt,gnomAD_exomes_POPMAX_AC,gnomAD_exomes_POPMAX_AF,gnomAD_exomes_POPMAX_nhomalt,gnomAD_exomes_NFE_AC,gnomAD_exomes_NFE_nhomalt,gnomAD_genomes_AC,gnomAD_genomes_AF,gnomAD_genomes_nhomalt,gnomAD_genomes_POPMAX_AC,gnomAD_genomes_POPMAX_AF,gnomAD_genomes_POPMAX_nhomalt,gnomAD_genomes_NFE_AC,gnomAD_genomes_NFE_AF,gnomAD_genomes_NFE_nhomalt"
#DBNSFP_ANNFIELDS_CLINVAR_VEP="clinvar_id,clinvar_clnsig,clinvar_trait,clinvar_review,clinvar_hgvs,clinvar_var_source,clinvar_MedGen_id,clinvar_OMIM_id,clinvar_Orphanet_id"
#DBNSFP_ANNFIELDS_VEP="$DBNSFP_ANNFIELDS_DEFAULT_VEP,$DBNSFP_ANNFIELDS_PRED_VEP,$DBNSFP_ANNFIELDS_GNOMAD_VEP,$DBNSFP_ANNFIELDS_CLINVAR_VEP"


#RGNSNM=$(basename -- $RGNS .tab)
#echo $RGNSNM
MVCF_FLT=$WD/MS319_PAN1.NORM_GQ20DP10_ANN_MAF001.vcf.gz
echo $MVCF_FLT
echo "Checkpoint 2"
## TODO: consider adding bcftools norm -d exact 
## subset samples & regions
START=$(date +%s.%N) && \
#bcftools view $MVCF_IN -R /cmg1scratch/PROJECTS/Serbian_MS_Aleksa/regions/ -S $SMPLS | \
bcftools view $MVCF_FLT \
#bcftools norm -m-any | \
bcftools +setGT -- -t q -n . -i 'FORMAT/GQ<20' | \
bcftools view --types snps | \
bcftools +fill-tags | \
bcftools view -i 'F_MISSING<1' | \
bcftools filter -e 'INFO/AC=0' | \
bcftools filter -i "QUAL>100" --threads 48 -Oz -o $MVCF_FLT && \
bcftools index -t --threads 48 $MVCF_FLT && \
END=$(date +%s.%N) && \
DIFF=$(echo "$END - $START" | bc) && \
echo bcftools: $DIFF
echo "Checkpoint 3"
START=$(date +%s.%N) && \
docker run -i \
	-v $DIRVEP:/data \
	-v $DIRNSFP:/dbNSFP \
	-v $WD:/input \
	-v $WD:/output:Z \
	ensemblorg/ensembl-vep:latest \
	bash -c "{
	cp -r /data/lofteeGRCh38/* /plugins
	vep -i /input/$(basename $MVCF_FLT) \
		-o /output/$(basename $MVCF_FLT .vcf.gz)_VEP-AM.vcf.gz \
		--fork 48 --cache --offline --format vcf --vcf --force_overwrite --compress_output bgzip -v \
		--dir_cache /data/ \
		--assembly GRCh38 \
		--everything \
		--shift_hgvs 0 \
		--allele_number \
		--plugin AlphaMissense,file=/data/AlphaMissense/AlphaMissense_hg38.tsv.gz
	tabix -p vcf /output/$(basename $MVCF_FLT .vcf.gz)_VEP-AM.vcf.gz
	}" && \
# bcftools index --threads 48 -t -f $WD/$(basename $MVCF_FLT .vcf.gz)_VEP.vcf.gz && \
END=$(date +%s.%N) && \
DIFF=$(echo "$END - $START" | bc) && \
echo VEP: $DIFF
