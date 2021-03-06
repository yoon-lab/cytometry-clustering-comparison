#########################################################################################
# Function to match cluster labels with manual gating (reference standard) population 
# labels and calculate precision, recall, and F1 score; for FlowCAP data sets
#
# Matching criterion: maximum F1 score
# Averages across populations: weighted by number of cells in true population
#
# Alternative function for FlowCAP-I data sets. Using same methodology as in FlowCAP 
# paper (Aghaeepour et al. 2013), i.e. max F1 score and weighting by population size.
# Results are averaged across populations for each sample, and then averaged across
# samples.
#
# Lukas Weber, August 2016
#########################################################################################


# arguments:
# - clus_algorithm: cluster labels from algorithm
# - clus_truth: true cluster labels
# (for both arguments: length = number of cells; names = cluster labels (integers))
helper_match_evaluate_FlowCAP_alternate <- function(clus_algorithm, clus_truth) {
  
  # number of detected clusters
  n_clus <- sum(!grepl("NA", names(table(clus_algorithm))))
  
  # split cluster labels by sample
  spl <- strsplit(clus_algorithm, split = "_")
  samples  <- as.numeric(sapply(spl, function(s) s[[1]]))
  clusters <- as.numeric(sapply(spl, function(s) s[[2]]))
  clusters_true <- clus_truth
  
  # evaluate individually for each sample (note some sample IDs may be missing)
  n_samples <- length(table(samples))
  sample_ids <- names(table(samples))
  res <- vector("list", n_samples)
  
  for (z in 1:n_samples) {
    
    # use sample ID instead of index z
    original_z <- z
    z <- as.numeric(sample_ids[z])
    
    # select sample z
    sel <- samples == z
    clus_algorithm <- clusters[sel]
    clus_truth <- clusters_true[sel]
    
    # remove unassigned cells (NA's in clus_truth)
    unassigned <- is.na(clus_truth)
    clus_algorithm <- clus_algorithm[!unassigned]
    clus_truth <- clus_truth[!unassigned]
    if (length(clus_algorithm) != length(clus_truth)) warning("vector lengths are not equal")
    
    tbl_algorithm <- table(clus_algorithm)
    tbl_truth <- table(clus_truth)
    
    # detected clusters in rows, true populations in columns
    pr_mat <- re_mat <- F1_mat <- matrix(NA, nrow = length(tbl_algorithm), ncol = length(tbl_truth))
    
    for (i in 1:length(tbl_algorithm)) {
      for (j in 1:length(tbl_truth)) {
        i_int <- as.integer(names(tbl_algorithm))[i]  # cluster number from algorithm
        j_int <- as.integer(names(tbl_truth))[j]  # cluster number from true labels
        
        true_positives <- sum(clus_algorithm == i_int & clus_truth == j_int, na.rm = TRUE)
        detected <- sum(clus_algorithm == i_int, na.rm = TRUE)
        truth <- sum(clus_truth == j_int, na.rm = TRUE)
        
        # calculate precision, recall, and F1 score
        precision_ij <- true_positives / detected
        recall_ij <- true_positives / truth
        F1_ij <- 2 * (precision_ij * recall_ij) / (precision_ij + recall_ij)
        
        if (F1_ij == "NaN") F1_ij <- 0
        
        pr_mat[i, j] <- precision_ij
        re_mat[i, j] <- recall_ij
        F1_mat[i, j] <- F1_ij
      }
    }
    
    # put back cluster labels (note some row names may be missing due to removal of unassigned cells)
    rownames(pr_mat) <- rownames(re_mat) <- rownames(F1_mat) <- names(tbl_algorithm)
    colnames(pr_mat) <- colnames(re_mat) <- colnames(F1_mat) <- names(tbl_truth)
    
    # match labels using highest F1 score (note duplicates are allowed)
    # use row and column names since some labels may have been removed due to unassigned cells
    labels_matched <- as.numeric(rownames(F1_mat)[apply(F1_mat, 2, which.max)])
    names(labels_matched) <- colnames(F1_mat)
    
    # precision, recall, F1 score, and number of cells for each matched cluster
    pr <- re <- F1 <- n_cells_matched <- rep(NA, ncol(F1_mat))
    names(pr) <- names(re) <- names(F1) <- names(n_cells_matched) <- names(labels_matched)
    
    for (i in 1:ncol(F1_mat)) {
      # use character names for row and column indices in case subsampling completely removes some clusters
      pr[i] <- pr_mat[as.character(labels_matched[i]), names(labels_matched)[i]]
      re[i] <- re_mat[as.character(labels_matched[i]), names(labels_matched)[i]]
      F1[i] <- F1_mat[as.character(labels_matched[i]), names(labels_matched)[i]]
      
      n_cells_matched[i] <- sum(clus_algorithm == labels_matched[i], na.rm = TRUE)
    }
    
    # use index z instead of sample ID (some sample IDs may be missing)
    res[[original_z]] <- list(pr = pr, re = re, F1 = F1, 
                              labels_matched = labels_matched, n_cells_matched = n_cells_matched, 
                              tbl_truth = tbl_truth)
  }
  
  # calculate mean precision, recall, F1 across true populations (with weighting by true population size)
  mean_pr_by_sample <- sapply(res, function(s) sum(s$pr * as.numeric(s$tbl_truth)) / sum(as.numeric(s$tbl_truth)))
  mean_re_by_sample <- sapply(res, function(s) sum(s$re * as.numeric(s$tbl_truth)) / sum(as.numeric(s$tbl_truth)))
  mean_F1_by_sample <- sapply(res, function(s) sum(s$F1 * as.numeric(s$tbl_truth)) / sum(as.numeric(s$tbl_truth)))
  
  # calculate means across samples
  mean_pr <- mean(mean_pr_by_sample)
  mean_re <- mean(mean_re_by_sample)
  mean_F1 <- mean(mean_F1_by_sample)
  
  return(list(n_clus = n_clus, 
              mean_pr_by_sample = mean_pr_by_sample, 
              mean_re_by_sample = mean_re_by_sample, 
              mean_F1_by_sample = mean_F1_by_sample, 
              mean_pr = mean_pr, 
              mean_re = mean_re, 
              mean_F1 = mean_F1))
}


