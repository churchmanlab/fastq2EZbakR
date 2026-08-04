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

        # -X 1.12 reproduces the SNP-calling behavior of the old bcftools 1.12 env. # Added in _MTC
        # The bcftools 1.13 release rewrote BAQ: it made BAQ partial/on-demand by
        # default AND changed the BAQ parametrization, so the newer default counts many
        # more alignment-artifact mismatches (~2x the SNPs). --full-BAQ alone is NOT
        # enough -- it only restores full-BAQ *scope* while keeping the new BAQ math.
        # The built-in "1.12" profile is the officially supported way to get the old
        # behavior back: it sets min_baseQ=13, tandemQ=100, min_frac=0.002, min_support=1,
        # and switches BAQ from partial (MPLP_REALN_PARTIAL) to full old-style (MPLP_REALN).
        bcftools mpileup --threads "$cpus" \
                         -X 1.12 \
                         -f "$genome_fasta" \
                         -b ./results/snps/bam.list \
                         -a AD,DP \
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