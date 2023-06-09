# Function to assess significance as to whether sample appears to have undergone genome doubling
# input:
# sample           - unique sample name
# seg.mat.minor    - segmented matrix with minor allele (e.g. seg.mat.LOH)
#                  - columns should be as follows: c("Sample","Chrom","Start","End","Num.probes","val")
# seg.mat.copy     - segmented total copy number matrix (columns as above)
# number.of.sim    - number of random simulations required;
# the function returns a p.val for every sample
# the function uses the limma weighted.median function

genome.doub.sig <- function(sample, seg.mat.minor, seg.mat.copy, number.of.sim = 10000) {
  print(sample)
  require(limma)

  sub.minor <- subset(seg.mat.minor, seg.mat.minor[, 1] == sample)
  sub.major <- subset(seg.mat.copy, seg.mat.copy[, 1] == sample)

  # define expected chr names
  chr.names <- c(
    "1", "1.5", "2", "2.5", "3", "3.5", "4", "4.5", "5", "5.5", "6", "6.5", "7", "7.5", "8", "8.5", "9",
    "9.5", "10", "10.5", "11", "11.5", "12", "12.5", "13.5", "14.5", "15.5", "16", "16.5", "17",
    "17.5", "18", "18.5", "19", "19.5", "20", "20.5", "21.5", "22.5"
  )


  # Determine whether given chromosome names are not equal to expected
  # note: input from ASCAT or ABSOLUTE must be modified (chromosome arms must be listed)
  if (!identical(unique(sub.minor[, 2]), chr.names)) {
    print("expected chr.names:")
    print(chr.names)
    stop(c(("seg.mat.minor chr.names!= expected chr.names")))
  }

  if (!identical(unique(sub.major[, 2]), chr.names)) {
    print("expected chr.names:")
    print(chr.names)
    stop(c(("seg.mat.copy chr.names!= expected chr.names")))
  }


  # sumarize minor allele copy numbers at chromosome arm.level
  chr.arm.ploidy.minor <- c()

  for (chr.arm in unique(sub.minor[, 2]))
  {
    sub.chr.minor <- rbind(subset(sub.minor, sub.minor[, 2] == chr.arm)[, 2:6])
    sub.chr.minor <- apply(sub.chr.minor, 2, as.numeric)
    sub.chr.minor <- rbind(sub.chr.minor)

    if (length(unique(sub.chr.minor[, 5])) == 1) {
      arm.ploidy <- unique(sub.chr.minor[, 5])
    } else if (length(unique(sub.chr.minor[, 5])) > 1) {
      arm.ploidy <- weighted.median(sub.chr.minor[, 5], w = sub.chr.minor[, 3] - sub.chr.minor[, 2], na.rm = T)
    }

    chr.arm.ploidy.minor <- c(chr.arm.ploidy.minor, arm.ploidy)
  }

  names(chr.arm.ploidy.minor) <- unique(sub.minor[, 2])

  # summarize total copy number at chromosome arm level
  # note: major alllele will be calculated by subtracting minor from total
  chr.arm.ploidy.major <- c()

  for (chr.arm in unique(sub.major[, 2]))
  {
    sub.chr.major <- rbind(subset(sub.major, sub.major[, 2] == chr.arm)[, 2:6])
    sub.chr.major <- apply(sub.chr.major, 2, as.numeric)
    sub.chr.major <- rbind(sub.chr.major)

    if (length(unique(sub.chr.major[, 5])) == 1) {
      arm.ploidy <- unique(sub.chr.major[, 5])
    } else if (length(unique(sub.chr.major[, 5])) > 1) {
      arm.ploidy <- weighted.median(sub.chr.major[, 5], w = sub.chr.major[, 3] - sub.chr.major[, 2], na.rm = T)
    }

    chr.arm.ploidy.major <- c(chr.arm.ploidy.major, arm.ploidy)
  }
  names(chr.arm.ploidy.major) <- unique(sub.major[, 2])

  # major from total and minor
  chr.arm.ploidy.major <- chr.arm.ploidy.major - chr.arm.ploidy.minor

  # calculate the total gains and losses
  total.aber <- sum(abs(chr.arm.ploidy.minor - 1)) + sum(abs(chr.arm.ploidy.major - 1))

  chr.probs <- c()

  # if no aberrations, cannot estimate GD; will assume no GD
  if (sum(total.aber) == 0) {
    p.val.genome.doubl <- c(1)
  }


  if (sum(total.aber) != 0) {
    # calculate the probability loss and gain for every arm
    for (chr.arm in chr.names)
    {
      chr.prob.A <- (chr.arm.ploidy.major[chr.arm] - 1)
      chr.prob.A <- c(
        sum(chr.prob.A[chr.prob.A > 0]) / total.aber,
        abs(sum(chr.prob.A[chr.prob.A < 0]) / total.aber)
      )
      names(chr.prob.A) <- c(paste(chr.arm, "_Again", sep = ""), paste(chr.arm, "_Aloss", sep = ""))


      chr.prob.B <- (chr.arm.ploidy.minor[chr.arm] - 1)
      chr.prob.B <- c(sum(chr.prob.B[chr.prob.B > 0]) / total.aber, abs(sum(chr.prob.B[chr.prob.B < 0]) / total.aber))
      names(chr.prob.B) <- c(paste(chr.arm, "_Bgain", sep = ""), paste(chr.arm, "_Bloss", sep = ""))

      chr.prob <- c(chr.prob.A, chr.prob.B)

      chr.probs <- c(chr.probs, chr.prob)
    }


    prop.major.even.obs <- length(which(chr.arm.ploidy.major >= 2)) / length(chr.arm.ploidy.major)
    # should probably set something as prop.major.even.obs p.val =0.001

    prop.major.even.sim <- c()
    k <- 1
    while (k <= number.of.sim) {
      chr.sim <- table(sample(names(chr.probs), total.aber, prob = chr.probs, replace = T))
      chr.sim.table <- chr.probs
      chr.sim.table <- rep(0, length(chr.probs))
      names(chr.sim.table) <- names(chr.probs)
      chr.sim.table[names(chr.sim)] <- chr.sim
      chr.sim.table <- cbind(
        chr.sim.table[seq(1, length(chr.sim.table), by = 4)],
        chr.sim.table[seq(2, length(chr.sim.table), by = 4)],
        chr.sim.table[seq(3, length(chr.sim.table), by = 4)],
        chr.sim.table[seq(4, length(chr.sim.table), by = 4)]
      )

      rownames(chr.sim.table) <- chr.names
      colnames(chr.sim.table) <- c("gain.A", "loss.A", "gain.B", "loss.B")
      chr.sim.major <- apply(cbind(
        c(1 + chr.sim.table[, 1] - chr.sim.table[, 2]),
        c(1 + chr.sim.table[, 3] - chr.sim.table[, 4])
      ), 1, max)


      prop.major.even <- length(which(chr.sim.major >= 2)) / length(chr.sim.major)

      prop.major.even.sim <- c(prop.major.even.sim, prop.major.even)

      k <- k + 1
    }

    p.val.genome.doubl <- length(which(prop.major.even.sim >= prop.major.even.obs)) / number.of.sim
    # note, will give p=0 if no simulation is greater than observed (i.e. technically incorrect)
    if (prop.major.even.obs == 1) {
      p.val.genome.doubl <- 0
    }
  }



  # return single p.val
  return(p.val.genome.doubl)
}


fun.GD.status <- function(GD.pval, ploidy.val) {
  GD.status <- c(NA)

  # is the patient diploid
  if (ploidy.val <= 2) {
    GD.status <- ifelse(GD.pval <= 0.001, "GD", "nGD")
  }

  # is the patient triploid
  if (ploidy.val == 3) {
    GD.status <- ifelse(GD.pval <= 0.001, "GD", "nGD")
  }

  # is the patient tetraploid
  if (ploidy.val == 4) {
    GD.status <- ifelse(GD.pval <= 0.05, "GD", "nGD")
  }

  # is the patient pentaploid
  if (ploidy.val == 5) {
    GD.status <- ifelse(GD.pval <= 0.5, "GD", "nGD")
  }
  # is the patient hexaploid
  if (ploidy.val == 6) {
    GD.status <- ifelse(GD.pval <= 1, "GD", "nGD")
  }

  return(GD.status)
}


###########################################
###########################################
## get seg.mat.copy ###################
###########################################

get.seg.mat.arm <- function(seg.mat.copy) {
  data(centromere)

  seg.mat.copy.arm <- c()

  for (sample in unique(seg.mat.copy[, 1]))
  {
    sub <- seg.mat.copy[seg.mat.copy[, 1] == sample, ]
    sub <- subset(seg.mat.copy, seg.mat.copy[, 1] == sample)
    sub.seg <- c()

    for (chr in as.character(unique(sub[, 2])))
    {
      # print(chr)
      chr.sub <- sub[sub[, 2] == chr, , drop = FALSE]

      # identify subset of segments that are on chr1 or chr1.5
      chr.p <- chr.sub[which(as.numeric(chr.sub[, 3]) < centromere[chr, 2]), , drop = FALSE]
      if (nrow(chr.p) != 0) {
        chr.p[as.numeric(chr.p[, 4]) > centromere[chr, 2], 4] <- round(centromere[as.character(chr), 2])
      }



      chr.q <- subset(chr.sub, as.numeric(chr.sub[, 4]) > centromere[chr, 2])
      if (nrow(chr.q) != 0) {
        chr.q[as.numeric(chr.q[, 3]) < centromere[chr, 2], 3] <- as.numeric(centromere[as.character(chr), 2]) + c(1)
        chr.q[, 2] <- paste(chr.q[, 2], ".5", sep = "")
      }



      chr.seg <- rbind(chr.p, chr.q)
      sub.seg <- rbind(sub.seg, chr.seg)
    }

    seg.mat.copy.arm <- rbind(seg.mat.copy.arm, sub.seg)
  }


  chr.names <- c(
    "1", "1.5", "2", "2.5", "3", "3.5", "4", "4.5", "5", "5.5", "6", "6.5", "7", "7.5", "8", "8.5", "9",
    "9.5", "10", "10.5", "11", "11.5", "12", "12.5", "13.5", "14.5", "15.5", "16", "16.5", "17",
    "17.5", "18", "18.5", "19", "19.5", "20", "20.5", "21.5", "22.5"
  )

  unique(seg.mat.copy.arm[, 2]) %in% chr.names


  seg.mat.copy.arm[seg.mat.copy.arm[, 2] == 21, 2] <- "21.5"
  seg.mat.copy.arm[seg.mat.copy.arm[, 2] == 15, 2] <- "15.5"
  seg.mat.copy.arm[seg.mat.copy.arm[, 2] == 22, 2] <- "22.5"
  seg.mat.copy.arm[seg.mat.copy.arm[, 2] == 13, 2] <- "13.5"
  seg.mat.copy.arm[seg.mat.copy.arm[, 2] == 14, 2] <- "14.5"


  if (length(unique(seg.mat.copy.arm[, 2])[which(!unique(seg.mat.copy.arm[, 2]) %in% chr.names)]) != 0) {
    stop("Cannot fit chromosome arms")
  }

  return(seg.mat.copy.arm)
}
