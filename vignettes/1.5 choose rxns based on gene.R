# This code is used to prepare the data for the map from model in BIGG format
source('model change.R')
source('transition for cellDesigner.R')

#part one
#prepare the reaction format
rxn <- read_excel("data/iML1515.xls",  sheet = "Reaction List")
metabolite <- read_excel("data/iML1515.xls",  sheet = "Metabolite List")
#analysis subsystem
analysis_subsystem <- rxn %>%
  count(Subsystem) %>%
  arrange(., desc(n)) 



#pre-process the metabolite and rxn
metabolite <- select(metabolite, Abbreviation,`Charged formula`, Charge)
metabolite$KEGGID <- NA
colnames(metabolite) <- c('Metabolite description', 'Metabolite formula', 'Charge', 'KEGGID')
metabolite$`Metabolite description` <- str_replace_all(metabolite$`Metabolite description`,"\\[.*?\\]", "")
#prepare the standard compartment
comparment <- unlist(str_extract_all(metabolite$`Metabolite description`, "_[:alpha:]$")) %>%
  str_replace_all(.,"_","[")
comparment <- paste(comparment, "]", sep = "")
for(i in seq_along(comparment)){
  metabolite$`Metabolite description`[i] <- str_replace_all(metabolite$`Metabolite description`[i],"_[:alpha:]$", comparment[i])
}
metabolite$`Metabolite description` <- str_replace_all(metabolite$`Metabolite description`,"__","_")




rxn0 <- select(rxn, Abbreviation, Reaction)
colnames(rxn0) <- c('ID0', 'Equation')
rxn_split <- splitRxnToMetabolite.Ecoli(rxn0, sep0 = "<=>")

#first remove the exchange reaction
exchange_index <- which(rxn_split$MetID=="")
exchange_id <- rxn_split$ID[exchange_index]
others <- which(rxn_split$ID %in% exchange_id ==FALSE)
rxn_split_refine <- rxn_split[others,]
rxn_split_refine <- select(rxn_split_refine, ID, MetID, compostion)
colnames(rxn_split_refine) <- c('v2','v3','type')
rxn_split_refine$subsystem <- getSingleReactionFormula(rxn$Subsystem,rxn$Abbreviation,rxn_split_refine$v2)
#rxn_split_refine$v2 <- str_replace_all(rxn_split_refine$v2,"R_","r_")

#prepare the standard compartment
comparment1 <- unlist(str_extract_all(rxn_split_refine$v3, "_[:alpha:]$")) %>%
  str_replace_all(.,"_","[")
comparment1 <- paste(comparment1, "]", sep = "")
for(i in seq_along(comparment1)){
  rxn_split_refine$v3[i] <- str_replace_all(rxn_split_refine$v3[i],"_[:alpha:]$", comparment1[i])
}
#rxn_split_refine$v3 <- str_replace_all(rxn_split_refine$v3, "M_", "")
rxn_split_refine$v3 <- str_replace_all(rxn_split_refine$v3,"__","_")
rxn_split_refine$v2 <- paste('r_',rxn_split_refine$v2, sep = "")


# choose the rxn based on gene
rxn_gene <- rxnGeneMapping(rxnid_gpr=rxn)

#analysis subsystem
gene_analysis <- rxn_gene %>%
  count(v1) %>%
  arrange(., desc(n)) 

# test
gene0 <- c('b0914','b3821')
rxn_contain_gene0 <- rxn_gene[rxn_gene$v1 %in% gene0, ]
rxn_choose <- unique(rxn_contain_gene0$v2)
rxn_choose <- paste('r_', rxn_choose, sep = "")
rxn_core_carbon <- rxn_split_refine[rxn_split_refine$v2 %in% rxn_choose,]


# Define the currency metabolite in each subsystem
currency_metabolites <- DefineCurrencyMet(rxn_split_refine, 
                                          subsystem0= NA,
                                          numberGEM=14,
                                          numberSubsystem=10)


# remove the reactions with only one metabolite
# if we do not remove the currency metabolite in the model then this step is mainly removed exchange reaction
rxn_core_carbon <- removeRxnWithSingleMet(rxn_split=rxn_core_carbon)


#--------------------------------------------------------------------------------------------
## define the base reactant and product for cellDesigner
#---------------------------------------------------------------------------------------------
rxn_core_carbon <- addBaseTypeIntoRxn(rxn_core_carbon, metabolite, currency_metabolites)


#---------------------------------------------------
# choose reaction based on the subsystem
#-----------------------------------------------------
rxnID_choose <- unique(rxn_core_carbon$v2)

#------------------------------------------------------------------
# produce the met, rxn and gpr used for the map production
#------------------------------------------------------------------
# prepare the metabolites formula
# this funcion is used to prepare the metabolite annotation for cell designer
met_annotation <- prepareMET(rxn_core_carbon, currency_metabolites,rxnID_choose)

# prepare the rxn formula
rxn_core_carbon_cellD0 <- prepareRXN(rxn_core_carbon,met_annotation,currency_metabolites)
# prepare the protein and gene
gpr <- prepareGPR(met_annotation)

#save the exampel data format for cell designer
#write.table(met_annotation,"result/met_annotation for example.txt", row.names = FALSE, sep = "\n")
#write.table(rxn_core_carbon_cellD0,"result/rxn_core_carbon_cellD0 for example.txt", row.names = FALSE, sep = "\n")
#write.table(gpr,"result/gpr for example.txt", row.names = FALSE, sep = "\n")

#------------------------------------------------------------------
# produce the file as the input for the cellDesigner
#------------------------------------------------------------------
produceInputForCellDesigner(met_annotation, 
                            gpr,
                            rxn_core_carbon_cellD0,
                            x_size=1200, 
                            y_size=2000)





#note
# solve the currency metabolites calculation in subsystem level
# but find more h+ from "Oxidative Phosphorylation", solved!
# 0.5, 1.5 as the metabolite, solved!
# h as the base reactant or product, 'r_TRDR'
# but for larger subsytem "Nucleotide Salvage Pathway"(150 rxn), it is still difficult to display it.
