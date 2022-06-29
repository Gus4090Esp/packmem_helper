#!/bin/bash

SPROD=1
EPROD=1
traj_dir="../../trajs_04_md"
gro=$traj_dir/mem.gro
PackMemPATH="/Desktop/software/packmem-master"
PackMem="python $PackMemPATH/PackMem.py"
ff="Charmm"

for (( i=$SPROD; i <= $EPROD; i++ )); do
  prefix=`printf "%i_%ins" $(( (i-1)*100 )) $(( i*100 ))`
  pwdir=`pwd`
  if [ ! -e $prefix ]; then mkdir $prefix; fi
  cd $prefix

  # make pdbs
  xtc="$traj_dir/${prefix}_mem.xtc"
  out="${prefix}_frm.pdb"
  echo 1 | gmx trjconv -f $xtc -s $gro -o $out -sep -dt 100 -pbc atom -ur tric
  rm -f \#*
  nfrms=`ls *pdb | wc -l`
  for (( j=0; j < $nfrms; j++ )); do
     f=`printf "${prefix}_frm%d.pdb" $j`
     out=`printf "${prefix}_frm%05d.pdb" $j`
     mv $f $out
  done

  # The following Total_*.txt files will contain the statistics for each type of
  # packing defects accumulated over all frames (one file per membrane leaflet)
  # Delete those files if they already exist before launching the main loop
  # (the -f flag avoids an error if the file doesn't exist)
  rm -f Total_Up_${prefix}_deep.txt
  rm -f Total_Lo_${prefix}_deep.txt
  rm -f Total_Up_${prefix}_shallow.txt
  rm -f Total_Lo_${prefix}_shallow.txt
  rm -f Total_Up_${prefix}_all.txt
  rm -f Total_Lo_${prefix}_all.txt

  # loop over all frames
  for (( pdbnum = 0; pdbnum < $nfrms; pdbnum++ )); do
      # print counter to screen
      name=`printf "${prefix}_frm%05d" $pdbnum`
      if [ -f ${name}_TotalLo_All.pdb ]; then continue; fi
      echo "$(date): PackMem running on $name.pdb"
      # launch PackMem for the 3 types of packing defects
      $PackMem -i $name.pdb \
               -r ${PackMemPATH}/vdw_radii_${ff}.txt \
               -p ${PackMemPATH}/param_${ff}.txt \
               -o $name -d 1.0 -t deep -v
      $PackMem -i $name.pdb \
               -r ${PackMemPATH}/vdw_radii_${ff}.txt \
               -p ${PackMemPATH}/param_${ff}.txt \
               -o $name -d 1.0 -t shallow -v
      $PackMem -i $name.pdb \
               -r ${PackMemPATH}/vdw_radii_${ff}.txt \
               -p ${PackMemPATH}/param_${ff}.txt \
               -o $name -d 1.0 -t all -v
      # accumulate packing defects of the current frame in Total_*.txt files
      cat  ${name}_Up_Deep_result.txt >> Total_Up_${prefix}_deep.txt
      cat  ${name}_Lo_Deep_result.txt >> Total_Lo_${prefix}_deep.txt
      cat  ${name}_Up_Shallow_result.txt >> Total_Up_${prefix}_shallow.txt
      cat  ${name}_Lo_Shallow_result.txt >> Total_Lo_${prefix}_shallow.txt
      cat  ${name}_Up_All_result.txt >> Total_Up_${prefix}_all.txt
      cat  ${name}_Lo_All_result.txt >> Total_Lo_${prefix}_all.txt
      # we no longer need the defects of the current frame
      rm -f ${name}_Up_Deep_result.txt
      rm -f ${name}_Lo_Deep_result.txt
      rm -f ${name}_Up_Shallow_result.txt
      rm -f ${name}_Lo_Shallow_result.txt
      rm -f ${name}_Up_All_result.txt
      rm -f ${name}_Lo_All_result.txt
      # pdbs that aren't needed
      rm -f ${name}_Lower.pdb
      rm -f ${name}_Upper.pdb
  done
  cd ..
done
