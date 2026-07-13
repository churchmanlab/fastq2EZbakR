# fastq2EZbakR — MTC customizations

This is a customized fork (`_MTC2`) of the upstream [fastq2EZbakR](https://github.com/isaacvock/fastq2EZbakR)
pipeline. It is built on the current upstream `main` and layers on the features below.
Every change is marked in the source with an `Added in _MTC` / `Changed in _MTC` comment.

## Summary of changes vs. upstream `main`

| # | Feature | What it does | Config keys | Files changed |
|---|---------|--------------|-------------|---------------|
| 1 | **SNP calling by counts** | Adds a lenient "SNP" strategy that flags any site where at least `snp_threshold` reads in the `-label` control show a mismatch, instead of relying on `bcftools call`'s genotype-likelihood model. Selectable via `snp_strategy`. | `snp_strategy` (`genome_likelihoods` \| `counts_in_control`), `snp_threshold` | `workflow/rules/bam2bakr.smk`, `workflow/scripts/bam2bakR/call_snps_bycounts.sh` (new), `config/config.yaml` |
| 2 | **BAM modification (remove read sets)** | Optionally drops reads overlapping a user-supplied BED (e.g. mito, PolIII) from the aligned BAM before downstream processing. All aligner outputs are routed through `results/alfullbam/` and the retained reads become `results/align/{sample}.bam`. | `modify_bam` (`yes` \| `no`), `path_to_removal_bed` | `workflow/rules/alignment.smk`, `workflow/rules/rsem.smk`, `workflow/rules/features.smk`, `workflow/rules/common.smk`, `config/config.yaml` |
| 3 | **Cell barcode + UMI + region carry-over** | Carries three per-read tags from the BAM into the cB / cUP / arrow output for 10X single-cell data: `cellbc` (`CB` tag), `umi` (`UB` tag), and `RE` (region: exonic/intronic/intergenic). Bulk BAMs that lack these tags get placeholders (`NO_BARCODE`, `NO_UMI`, `-`). | *(always on; see note in `final_output`)* | `workflow/scripts/bam2bakR/mut_call.py`, `workflow/scripts/bam2bakR/merge_features_and_muts.R`, `config/config.yaml` |
| 4 | **`minqual` as a direct Phred score** | Removes the legacy `+33` ASCII offset from every base-quality comparison, so `minqual` is interpreted directly as a Phred score with an inclusive minimum (a base is counted when Phred >= `minqual`). Default lowered to `35`. | `minqual` (default `35`) | `workflow/scripts/bam2bakR/mut_call.py`, `config/config.yaml` |

## Notes

- **Single-cell carry-over (feature 3)** is only produced by the standard (DuckDB) merge path.
  It is **not** added when `lowRAM: True`, so keep the default `lowRAM: False` if you need
  `cellbc` / `umi` / `RE` in the output. (Also noted inline in `config/config.yaml`.)
- **cU-trial quality filter (feature 4):** at the `mutPos`/cU-trial counting site, this fork keeps
  the quality filter (`b[2] >= minQual`) so the trial *denominator* uses the same threshold as the
  mutation *numerator*. This is a deliberate consistency fix relative to the original `_MTC` code,
  which dropped that filter.

## Intentionally NOT ported from `_MTC`

These `_MTC` features were left out of `_MTC2` on purpose:

| Feature | Reason |
|---------|--------|
| PCR-duplicate removal (`remove_duplicates_with_UMI`, `removePCRdupsFromBAM_*.py`) | Excluded (bulk UMI handling) |
| fastp hard-clipping / second trimming pass (`do_hardclipping`, `fastp_hardclip_parameters`) | Excluded (fastp trimming differences) |
| featureCounts `-M` multi-mapper flag (`fc_genes_extra` / `fc_exons_extra`) | Left at upstream `main`'s `--nonOverlap 0` |
