#!/bin/bash
set -euo pipefail

# Cute trick to deal with fact that there is an uncertain number of control sample
    # control_samples becomes array with all args
    # remove args that I know aren't the actual control_samples

cpus=$1
nsamps=$2
output_txt=$3
output_vcf=$4
snp_counts=$5
genome_fasta=$6

shift 7

control_samples=("$@")




if [[ "$nsamps" -gt 0 ]] 
then
    # Loop through control samples:
        declare -a bam_list=()

        for cs in ${control_samples[@]}; do
            name=$(echo "$cs" | cut -d '/' -f 3 | rev | cut -c8- | rev)

            sorted="./results/snps/"$name"_sort.bam"

            samtools sort -@ "$cpus" -o ./results/snps/"$name"_sort.bam "$cs"
            samtools index -@ "$cpus" ./results/snps/"$name"_sort.bam
            #bcftools mpileup --threads "$cpus" -f "$genome_fasta" ./results/snps/"$name"_sort.bam | bcftools call --threads "$cpus" -mv > ./results/snps/snp-"$name".vcf

            bam_list+=( "$sorted" )

        done


        echo "${bam_list[@]}" | tr ' ' '\n' > ./results/snps/bam.list

        # --full-BAQ reproduces the SNP-calling behavior of the old bcftools 1.12 env. # Added in _MTC
        # From bcftools 1.13 on, mpileup applies BAQ only in problematic regions by
        # default; 1.12 ran full BAQ on all reads. Restoring full BAQ downweights more
        # alignment-artifact mismatches, matching the smaller SNP set the 1.12 env produced.
        # (-Q/-q are left at their defaults of 13/0, which are unchanged across versions.)
        bcftools mpileup --threads "$cpus" \
                         -f "$genome_fasta" \
                         -b ./results/snps/bam.list \
                         -a AD,DP \
                         --full-BAQ \
                         -Ou \
        | bcftools view --threads "$cpus" -i "FORMAT/AD[0:1]>=$snp_counts" -o ./results/snps/Min${snp_counts}_sites.vcf


		# Make snp.txt
		grep -v 'INDEL' ./results/snps/Min${snp_counts}_sites.vcf > $output_vcf
		awk '{if($1 !~ /^#/){split($5,alt,","); print $4 ":" alt[1] ":" $1 ":" $2}}' $output_vcf | sort | uniq > $output_txt
        
        echo '* SNPs called and snp.txt generated'

else
    touch "$output_txt"
    touch "$output_vcf"
fi


rm -f 0