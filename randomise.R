

#' Balanced cluster randomisation across all arms
#'
#' @param d 
#'
#' @return
#' @export
#'
#' @examples
BR_alloc <- function(ldat, idxstart, idxend, interim_idx){


  # Number arms
  K <- ldat$arm_status$K

  # # Number of clusters
  J <- length(unique(clustid[idxstart:idxend]))
  
  # Say if we have four arms 1 2 3 4,
  # and arms 1 and 3 are active, ie ldat$arm_status$active = T F T F,
  # then the active_arms variable will contain 1 3
  active_arms <- (1:K)[ldat$arm_status$active]
  

  # Add the randomised treatment allocation.
  # Enforce allocation of first K clusts to set of distinct arms.
  if(interim_idx == 1){
    
    message(get_hash(), " BR_alloc first interim enforcing all active arms to have some allocation ", 
            paste0(active_arms, collapse = " "))

    rand_arm <- c(sample(active_arms, size = length(active_arms), replace = F),
                  sample(active_arms, size = J-length(active_arms), replace = T))
    
  } else {
    
    message(get_hash(), " BR_alloc using active arms ")
    
    rand_arm <- c(sample(active_arms, size = J, replace = T))
  }
  
  rep(rand_arm, times = table(clustid[idxstart:idxend]))

}


#' Response adaptive randomisation at the cluster level
#'
#' @param d 
#' @param lpar 
#'
#' @return
#' @export
#'   
#' @examples
#' 
#' d, palloc, var_k, lpar
RAR_clust_alloc <- function(clustid, a_s, idxstart, idxend, interim_idx){
  
  
  # # Number of clusters
  J <- length(unique(clustid[idxstart:idxend]))
  
  # Initialise
  a_s$p_rand <- rep(0, a_s$K)
  
  # Say if we have four arms 1 2 3 4,
  # and arms 1 and 3 are active, ie ldat$arm_status$active = T F T F,
  # then the active_arms variable will contain 1 3
  
  arms_for_rar <- which((a_s$arms_in_post & a_s$active) == T)
  # Soc never gets rar
  arms_for_rar <- arms_for_rar[arms_for_rar != 1]
  
  # An arm might be active but this might be the first time it is randomised
  # to so it will not be in the posterior yet.
  active_arms <- (1:a_s$K)[a_s$active]
  
  
  if(interim_idx == 1){
    
    message(get_hash(), " first interim balanced alloc total arms ", 
            a_s$K, " active_arms ",
            paste0(active_arms, collapse = " "))
    
    rand_arm <- c(sample(active_arms, size = length(active_arms), replace = F),
                  sample(active_arms, size = J-length(active_arms), replace = T))
    rand_arm <- rep(rand_arm, times = table(clustid[idxstart:idxend]))
    a_s$p_rand[active_arms] <- 1/length(active_arms)
    
    return(list(rand_arm = rand_arm, arm_status = a_s))
    
  } else {
    
    # Initialise
    palloc <- numeric(a_s$K)
    vark <- numeric(a_s$K)
    
    # Set
    palloc[arms_for_rar] <- a_s$p_beat_soc[arms_for_rar]
    vark[arms_for_rar] <- a_s$var_k[arms_for_rar]
    r <- sqrt(palloc * vark / (a_s$nk+1) )
    
    message(get_hash(), " arms_enabled_for_anly ", 
            paste0(a_s$enabled_for_anly, collapse = " "), " a_s$active ",
            paste0(a_s$active, collapse = " "))

    # This deals with the situation where we have an activated arm but it was not included
    # in the previous analysis and so does not appear in posterior. This could happen because
    # the outcome is not available immediately. Thus even though we gaurantee that all arms
    # are randomised during activation, it is possible that the new arm contains no observed data.

    apply_balanced_alloc <- rep(F, a_s$K)
    
    # Start with a default position that balance is true in any arms that are 
    # to commence at this interim
    apply_balanced_alloc[interim_idx >= a_s$enabled_for_anly] <- T
    # Set the inactive ones to not receive balanced alloc (they receive no alloc)
    apply_balanced_alloc[!a_s$active] <- F
    # Set the rar arms not to receive balanced alloc
    apply_balanced_alloc[arms_for_rar] <- F
    
    

    mass_remaining <- 1
    if(sum(apply_balanced_alloc)>0){

      message(get_hash(), " apply_balanced_alloc to arms ",
              paste0(apply_balanced_alloc, collapse = " "))

      a_s$p_rand[apply_balanced_alloc] <- 1/sum(a_s$active)

      mass_remaining <- 1 - sum(a_s$p_rand[apply_balanced_alloc])
    }

    a_s$p_rand[arms_for_rar] <- (r/sum(r))[arms_for_rar] * mass_remaining
    
    message(get_hash(), " rand probs p_rand ", 
            paste0(round(a_s$p_rand, 3), collapse = " "))
    message(get_hash(), " apply_balanced_alloc ", 
            paste0(apply_balanced_alloc, collapse = " "))
    
    
    # Need to consider what to do after one arm becomes superior
    
    if(sum(apply_balanced_alloc)>0){
      
      # Note that in the first sample statement, p_rand is irrelevant as we want to 
      # guarantee at least 1 unit to each arm and in the 
      # second sample statement p_rand = 0 takes care of inactive arms.
      rand_arm <- c(sample(active_arms, 
                           size = length(active_arms), 
                           replace = F),
                    sample(1:a_s$K, 
                           size = J-length(active_arms), 
                           replace = T, 
                           prob = a_s$p_rand))
    }
    else {
      
      rand_arm <- c(sample(1:a_s$K, 
                           size = J, 
                           replace = T, 
                           prob = a_s$p_rand))
    }

    tbl <- table(rand_arm)
    message(get_hash(), " allocated ", 
            paste0(as.numeric(tbl), collapse = " "), " to active arms ", 
            paste0(active_arms, collapse = " "))
  

    return(list(rand_arm = rep(rand_arm, 
                               times = table(clustid[idxstart:idxend])), 
                arm_status = a_s))
  }


}







#' Response adaptive randomisation at the individual level
#'
#' @param id patient id
#' @param a_s arm status
#' @param idxstart index marking the first id to be randomised 
#' @param idxend index marking the last id to be randomised 
#' @param interim_idx current interim index 
#'
#' @return
#' @export
#'   
#' @examples
#' 
#' d, palloc, var_k, lpar
RAR_alloc <- function(id, a_s, idxstart, idxend, interim_idx){
  
  
  # # Number of individuals
  n_pt <- length(unique(id[idxstart:idxend]))
  
  # Initialise randomisation probabilities
  a_s$p_rand <- rep(0, a_s$K)
  
  # Say if we have four arms 1 2 3 4,
  # and arms 1 and 3 are active, ie ldat$arm_status$active = T F T F,
  # then the active_arms variable will contain 1 3
  
  arms_for_rar <- which((a_s$arms_in_post & a_s$active) == T)
  # Soc never gets rar
  arms_for_rar <- arms_for_rar[arms_for_rar != 1]
  
  # An arm might be active but this might be the first time it has been randomised
  # to and therefore it will not be in the posterior yet and therefore we cannot 
  # compute any probability measures.
  active_arms <- (1:a_s$K)[a_s$active]
  
  
  if(interim_idx == 1){
    
    message(get_hash(), " first interim balanced alloc total arms ", 
            a_s$K, " active_arms ",
            paste0(active_arms, collapse = " "))
    
    # Simple randomisation for first interim
    rand_arm <- c(sample(active_arms, size = length(active_arms), replace = F),
                  sample(active_arms, size = n_pt - length(active_arms), replace = T))
    
    a_s$p_rand[active_arms] <- 1/length(active_arms)
    
    return(list(rand_arm = rand_arm, arm_status = a_s))
    
  } else {
    
    # Initialise
    palloc <- numeric(a_s$K)
    vark <- numeric(a_s$K)
    
    # Set
    palloc[arms_for_rar] <- a_s$p_beat_soc[arms_for_rar]
    vark[arms_for_rar] <- a_s$var_k[arms_for_rar]
    r <- sqrt(palloc * vark / (a_s$nki + 1) )
    
    message(get_hash(), " arms_enabled_for_anly ", 
            paste0(a_s$enabled_for_anly, collapse = " "), " a_s$active ",
            paste0(a_s$active, collapse = " "))
    
    # This deals with the situation where we have an activated arm but it was not included
    # in the previous analysis and so does not appear in posterior. This could happen because
    # the outcome is not available immediately. Thus even though we gaurantee that all arms
    # are randomised during activation, it is possible that the new arm contains no observed data.
    
    apply_balanced_alloc <- rep(F, a_s$K)
    
    # Start with a default position that balance is true in any arms that are 
    # to commence at this interim
    apply_balanced_alloc[interim_idx >= a_s$enabled_for_anly] <- T
    # Set the inactive ones to not receive balanced alloc (they receive no alloc)
    apply_balanced_alloc[!a_s$active] <- F
    # Set the rar arms not to receive balanced alloc
    apply_balanced_alloc[arms_for_rar] <- F
    

    mass_remaining <- 1
    if(sum(apply_balanced_alloc)>0){
      
      message(get_hash(), " apply_balanced_alloc to arms ",
              paste0(apply_balanced_alloc, collapse = " "))
      
      a_s$p_rand[apply_balanced_alloc] <- 1/sum(a_s$active)
      
      mass_remaining <- 1 - sum(a_s$p_rand[apply_balanced_alloc])
    }
    
    a_s$p_rand[arms_for_rar] <- (r/sum(r))[arms_for_rar] * mass_remaining
    
    message(get_hash(), " rand probs p_rand ", 
            paste0(round(a_s$p_rand, 3), collapse = " "))
    message(get_hash(), " apply_balanced_alloc ", 
            paste0(apply_balanced_alloc, collapse = " "))
    
    
    # Need to consider what to do after one arm becomes superior
    
    if(sum(apply_balanced_alloc)>0){
      
      # Note that in the first sample statement, p_rand is irrelevant as we want to 
      # guarantee at least 1 unit to each arm and in the 
      # second sample statement p_rand = 0 takes care of inactive arms.
      rand_arm <- c(sample(active_arms, 
                           size = length(active_arms), 
                           replace = F),
                    sample(1:a_s$K, 
                           size = n_pt - length(active_arms) , 
                           replace = T, 
                           prob = a_s$p_rand))
    }
    else {
      
      rand_arm <- c(sample(1:a_s$K, 
                           size = n_pt, 
                           replace = T, 
                           prob = a_s$p_rand))
    }
    
    tbl <- table(rand_arm)
    message(get_hash(), " allocated ", 
            paste0(as.numeric(tbl), collapse = " "), " to active arms ", 
            paste0(active_arms, collapse = " "))
    
    
    return(list(rand_arm = rand_arm, 
                arm_status = a_s))
  }
  
  
}