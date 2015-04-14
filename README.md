The following an is an example script to assess the clonality of one TCGA sample, 'TCGA-BT-A42C'. 

rm(list=ls())
setwd("~/Downloads/McGranahan_data/Estimate_Clonality_Package/")
install.packages("EstimateClonality_1.0.tar.gz",repos=NULL,type='source')
library("EstimateClonality")
clonality.estimation(mutation.table.loc="BLCA.mutation.table.txt"
                     ,seg.mat.loc="tcga.blca.seg.hg19.rdata"
                     ,data.type='TCGA_BLCA'
                     ,TCGA.barcode="TCGA-BT-A42C"
                     ,ANALYSIS.DIR="example2/")



