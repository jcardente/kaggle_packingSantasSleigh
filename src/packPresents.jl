# ------------------------------------------------------------
# Julia solution to Kaggle 2013 Holiday Competition.
#
# http://www.kaggle.com/c/packing-santas-sleigh
#
# John Cardente
# jcardente@gmail.com
#
#
# This file contains the code for my final solution. 
# ------------------------------------------------------------

using Stats;
using Debug;

# ------------------------------------------------------------
# PARAMETERS
# ------------------------------------------------------------

leveldim  = 1000;
levelarea = leveldim * leveldim;


# ------------------------------------------------------------
# TYPES
# ------------------------------------------------------------

# NB - Julia doesn't allow types to be redefined. To make
#      code re-loadable, only define types if they don't
#      already exist.

if (!isdefined(:Region))
type Region
  xstart::Int
  ystart::Int
  xsize::Int
  ysize::Int
  zstart::Int
end

 function Region(xstart, xsize, ystart, ysize)
   Region(xstart, xsize, ystart, ysize, 0);
 end
end

if (!isdefined(:Present))
type Present
  id
  xsize::Int
  ysize::Int
  zsize::Int
  xstart::Int
  ystart::Int
  zstart::Int
end

function Present(id, xsize, ysize, zsize)
  Present(id, xsize, ysize, zsize, 0, 0, 0)
 end
end

if (!isdefined(:SplitGuillotine))
immutable SplitGuillotine
end
end

if (!isdefined(:SplitMaximal))
immutable SplitMaximal
end
end



# ------------------------------------------------------------
# GEOMETRY 
# ------------------------------------------------------------



macro overlap2d(a,b)
quote
 (!((($(a).xstart + $(a).xsize -1) < $(b).xstart) ||
    ($(a).xstart > ($(b).xstart + $(b).xsize -1)) ||
    (($(a).ystart + $(a).ysize -1) < $(b).ystart) ||
    ($(a).ystart > ($(b).ystart + $(b).ysize -1))))
end
end

macro overlap3d(a,b)
quote
 (!((($(a).xstart + $(a).xsize -1) < $(b).xstart) ||
    ($(a).xstart > ($(b).xstart + $(b).xsize -1)) ||
    (($(a).ystart + $(a).ysize -1) < $(b).ystart) ||
    ($(a).ystart > ($(b).ystart + $(b).ysize -1)) ||
    (($(a).zstart - $(a).zsize + 1) < $(b).zstart) ||
    ($(a).zstart > ($(b).zstart - $(b).zsize + 1))))
end
end


macro rectcovers(axstart, aystart, axend, ayend,
                 bxstart, bystart, bxend, byend)
quote
(($axstart <= $bxstart) &&
($axend   >= $bxend)   &&
($aystart <= $bystart) &&
($ayend   >= $byend  ))
end
end 



macro flipcoord(start, size)
quote
  (leveldim + 1) - ($start + $size - 1)
end
end


macro zmapget(zmap, xstart, ystart, xsize, ysize)
quote
 $zmap[$xstart:($xstart + $xsize -1),
       $ystart:($ystart + $ysize -1)]
end
end



# ------------------------------------------------------------
# PRESENTS
# ------------------------------------------------------------


function loadpresents(inputfile)
  # Load present CSV file and create array of composite types.
  presentscsv = readcsv(inputfile, Int, has_header=true)[1];
  presentscsv = presentscsv[sortperm(presentscsv[:,1]),:];

  # Sort the per-present dimensions from smallest to
  # largest. Essentially, rotate the present so that the largest
  # dimension is in the Z direction.
  presentscsv[:,2:4] = sort(presentscsv[:,2:4],2);

  # Create a list of composite types to represent presents.
  presents = Present[];
  for i in 1:size(presentscsv,1)
    push!(presents, Present(presentscsv[i,1], presentscsv[i,2],
                            presentscsv[i,3], presentscsv[i,4]))
  end

  presents;
end


function placepresent!(r::Region, p::Present, currentz)
 # Put present in region. Might need
 # to rotate to fit it
 if ((p.xsize > r.xsize) ||
     (p.ysize > r.ysize))
   tmp = p.xsize;
   p.xsize = p.ysize;
   p.ysize = tmp;
 end
    
 p.xstart = r.xstart;
 p.ystart = r.ystart;
 p.zstart = currentz;
end



function resetpresents(presents)
  # Reset present locations
  for i in 1:length(presents)
    presents[i].xstart = 0;
    presents[i].ystart = 0;
    presents[i].zstart = 0;
  end

end


# ------------------------------------------------------------
# FREE SPACES
# ------------------------------------------------------------
                       
function findregion(p::Present, rlist, zadjust)
 # Find a freespace region for present.
 # Choose area that fits and results in the
 # lowest amount of leftover free space.
 pdims = sort([p.xsize,p.ysize],rev=true); 
 parea = p.xsize * p.ysize;
 best  = 0;
 
 rareas = [r.xsize * r.ysize for r in rlist]; 
 ridxs  = [x::Int for x in 1:length(rlist)];
 sort!(ridxs, lt= (a,b) -> (rareas[a] < rareas[b]));
 goodareas = filter( x -> (rareas[x] >= parea), ridxs);
 if (length(goodareas) > 0) 
   startidx = first(goodareas);
   for i in startidx:length(ridxs)
     idx = ridxs[i];
     r   = rlist[idx];
     if (all(sort([r.xsize,r.ysize],rev=true) .>=
              pdims))
       best      = idx;
       break;
     end
   end
 end

 best;
end


function findoverlapping(p, rlist)
 # Find the free space regions that contain at least
 # a part of the specified present (or region)
 overlapidxs = Int[];
 for idx in 1:length(rlist)
   # Using the separating axis test
   #
   # http://stackoverflow.com/questions/306316/determine-if-two-rectangles-overlap-each-other?lq=1
   r = rlist[idx];      
   if (@overlap2d(r,p))
     push!(overlapidxs, idx);
   end   
 end 
 overlapidxs;
end



# NB - using types to select different freespace splitting 
#      via method dispatch. 

function splitfreespace(r::Region, p::Present, method::SplitGuillotine)
  # Create new regions by splitting region
  # according to the size. Assumes present is
  # placed in (1,1) position.
  xsize = p.xsize;
  ysize = p.ysize;
  @assert(r.xsize >= xsize);
  @assert(r.ysize >= ysize);
  
  newregions = Region[];
  if (r.xsize > r.ysize)
     if ((r.xsize - xsize) > 0)
       push!(newregions,
             Region(r.xstart + xsize,
                    r.ystart,
                    r.xsize - xsize,
                    r.ysize,
                    r.zstart));
     end

     if ((r.ysize - ysize) > 0)
       push!(newregions,
             Region(r.xstart,
                    r.ystart + ysize,
                    xsize,
                    r.ysize - ysize,
                    r.zstart));
      end
                   
  else
     if ((r.ysize - ysize) > 0)
       push!(newregions,
             Region(r.xstart,
                    r.ystart + ysize,
                    r.xsize,
                    r.ysize - ysize,
                    r.zstart));
     end

     if ((r.xsize - xsize) > 0)
       push!(newregions,
             Region(r.xstart + xsize,
                    r.ystart,
                    r.xsize - xsize,
                    ysize,
                    r.zstart));
      end                 
  end

  newregions;
end


function splitfreespace(r::Region, p::Present, method::SplitMaximal)
   # Split region into maximal areas. 
   newregions = Region[];

   if (p.xstart > r.xstart)
     push!(newregions,
           Region(r.xstart,
                  r.ystart,
                  (p.xstart - r.xstart),
                  r.ysize,
                  r.zstart));
   end

   if (p.ystart > r.ystart)
     push!(newregions,
           Region(r.xstart,
                  r.ystart,
                  r.xsize,
                  (p.ystart - r.ystart),
                  r.zstart));
   end

   if ((p.xstart + p.xsize) < (r.xstart + r.xsize))
     push!(newregions,
           Region(p.xstart + p.xsize,
                  r.ystart,
                  ((r.xstart + r.xsize) - (p.xstart + p.xsize)),
                  r.ysize,
                  r.zstart));
   end

   if ((p.ystart + p.ysize) < (r.ystart + r.ysize))
     push!(newregions,
           Region(r.xstart,
                  p.ystart + p.ysize,
                  r.xsize,
                  ((r.ystart + r.ysize) - (p.ystart + p.ysize)),
                  r.zstart));
   end

  newregions;
end


function findredundant(rlist)
 redidxs = Set();
 for idx1 in 1:length(rlist)
  r1 = rlist[idx1];
  for idx2 in 1:length(rlist)
     if (idx1 == idx2)
       continue;
     end     
     r2 = rlist[idx2];     
     if (@rectcovers(r2.xstart, r2.ystart, r2.xstart + r2.xsize, r2.ystart + r2.ysize,
                     r1.xstart, r1.ystart, r1.xstart + r1.xsize, r1.ystart + r1.ysize))
       if (!(idx2 in redidxs))
         push!(redidxs, idx1);
         break;
       end
     end
   end
 end

 redidxs;
end


function splitfreespace(r::Region, p::Present)
  # By Default use Guillotine freespace splitting
  splitfreespace(r,p,SplitGuillotine());
end



# ------------------------------------------------------------
# PACKING
# ------------------------------------------------------------


function packSimple(presents, candidates, currentz, zadjust, splitmethod)

 # Select a window of presents that ideally fill a level.
 warea  = 0; 
 optpackidxs = Int[];
 for i = candidates
   warea += presents[i].xsize * presents[i].ysize;
   if (warea >= levelarea)
     break
   end
   push!(optpackidxs, i);
 end

 # Pack presents using a modified shelf algorithm
 # Pack as many as possible in present ID order.
 # Stop after first failure to pack
 packidxs   = optpackidxs;
 freespaces = [Region(1,1,leveldim,leveldim,currentz)];
 packed     = Int[];
 while ((length(packidxs) > 0) &&
        (length(freespaces) > 0))
 
   # Select next present
   pidx = shift!(packidxs);
   p    = presents[pidx];
 
   # Find the best free space region to
   # put it in
   ridx = findregion(p, freespaces, zadjust);
   if (ridx == 0)
     # Didn't find a freespace region for this
     # present. Don't pack it. In fact, stop packing
     # this level to avoid out-of-order penalties.
     break;
   end
   # Place present in region, record that it got
   # packed and update the maximum zdepth
   placepresent!(freespaces[ridx], p, currentz);
   push!(packed, pidx);
   # Find overlapping regions, remove them, and replace
   # with remainder freespaces.
   roverlaps = findoverlapping(p, freespaces);
   @assert(length(roverlaps) >= 1);
   newregions = Region[];
   for roidx in roverlaps            
     # Compute new free space
     append!(newregions, splitfreespace(freespaces[roidx], p, splitmethod));
   end
   
   # Remove original freespace from list and
   # add new freespaces.
   freespaces = freespaces[filter(idx -> !(idx in roverlaps),
                           1:length(freespaces))]; 
   prepend!(freespaces, newregions);
   # Remove redundant free spaces
   redidxs = findredundant(freespaces);
   if (length(redidxs) > 0)
     freespaces = freespaces[filter(idx -> !(idx in redidxs),
                             1:length(freespaces))];
   end        
 end

 packed;
end


function packBinSearch(presents, candidates, currentz, zadjust, splitmethod)
  
 # Select a window of presents that ideally fill a level.
 #println("  -- Picking optimal packidxs");
 # Reserve some area to limit aggressiveness 
 warea  = 5000; 
 optpackidxs = Int[];
 for i = candidates
   warea += presents[i].xsize * presents[i].ysize;
   if (warea >= levelarea)
     break
   end
   push!(optpackidxs, i);
 end
 
 # The penalty for packing out of order dominates. However
 # efficient packing requires sorting the packages by size.
 # To balance the two requirements, we
 # 1. Pick a set of presents to pack that fill an entire level
 # 2. Sort them by size
 # 3. Pack them
 # 4. Check for out-of-order packing
 # 5. If none, success.
 # 6. If some, then undo packing and try again with one less present.
 #
 #println("  --Packing");
 # NB - A binary search is used to determine the most
 #      presents that can be packed in this level based
 #      on sequential ID but packing in order of
 #      decreasing area. Since most of the presents will fit
 #      we bias the starting index to almost the whole range.
 #      We set the initial bad index to the max+1 just in
 #      case all the presents can be packed - setting to
 #      max+1 allows the last present to also be packed. 
 optgoodidx = 1; 
 optbadidx  = length(optpackidxs); 
 optsearchidx = optbadidx; #max(1, ifloor(optbadidx * .95));
 packed     = Int[];
 success    = false;    
 while (!success)
   # Pack presents using a modified shelf algorithm
   # Pick subset of optimal presents for this level.
   # Sort based on area to pack largest first for
   # better efficiency.
   packidxs   = optpackidxs[1:optsearchidx];
   sort!(packidxs, by= i -> (presents[i].ysize * presents[i].xsize), rev=true);
   
   freespaces = [Region(1,1,leveldim,leveldim,currentz)];
   packed     = Int[];
   while ((length(packidxs) > 0) &&
          (length(freespaces) > 0))
   
     # Select next present
     pidx = shift!(packidxs);
     p    = presents[pidx];
   
     # Find the best free space region to
     # put it in
     ridx = findregion(p, freespaces, zadjust);
     if (ridx == 0)
       # Didn't find a freespace region for this
       # present. Don't pack it. In fact, stop packing
       # this level to avoid out-of-order penalties.
       break;
     end
     # Place present in region, record that it got
     # packed and update the maximum zdepth
     placepresent!(freespaces[ridx], p, currentz);
     push!(packed, pidx);
     # Find overlapping regions, remove them, and replace
     # with remainder freespaces.
     roverlaps = findoverlapping(p, freespaces);
     @assert(length(roverlaps) >= 1);
     newregions = Region[];
     for roidx in roverlaps            
       # Compute new free space
       append!(newregions, splitfreespace(freespaces[roidx], p, splitmethod));
     end
     
     # Remove original freespace from list and
     # add new freespaces.
     freespaces = freespaces[filter(idx -> !(idx in roverlaps),
                             1:length(freespaces))]; 
     prepend!(freespaces, newregions);
     # Remove redundant free spaces
     redidxs = findredundant(freespaces);
     if (length(redidxs) > 0)
       freespaces = freespaces[filter(idx -> !(idx in redidxs),
                               1:length(freespaces))];
     end        
   end
   
   nfree = length(freespaces);
   npacked = length(packed);
   
   if ((length(packidxs) > 0) &&
       (minimum(packidxs) < maximum(packed)))
     # Rats, there is an ordering issue.
     for pidx in packed
        presents[pidx].xstart = 0;
        presents[pidx].ystart = 0;
        presents[pidx].zstart = 0;           
     end
     # OK, figure out the next binary search range.
     optbadidx    = optsearchidx;
     optsearchidx = ifloor((optgoodidx + optbadidx)/2);
   if (optbadidx == optgoodidx)
       # NB - the packing should be deterministic in that
       #      a set of presents successfully packed before
       #      should be packable again. However, testing
       #      revealed that this might not be the case.
       #
       #      To work around this, check to see if the
       #      optgoodidx is equal to the optbadidx. If
       #      so, reduce the optgood idx by one.
      optgoodidx -=1;
      optsearchidx = optgoodidx;         
     end
   #println(" Bad: $optgoodidx $optsearchidx $optbadidx $nfree $npacked");
   else
     # Success, we packed all the presents without any ordering
     # issues. Check if this is the largest set from binary
     # search.
     #
     # NB - If we pack the optimal set on the first try
     #      searchidx will be equal to optbadidx. Therefore
     #      need to exit if the distance is 1 OR 0.
     if ((optbadidx - optsearchidx) <= 1)
       # The binary search has converged. Sort and exit.
       sort!(packed);        
       success = true;
       #@assert(!any((packed[2:length(packed)] .- packed[1:(length(packed)-1)]) .> 1));          
       #println("Conv: $optgoodidx $optsearchidx $optbadidx $nfree $npacked");        
   else
       # Found a good lower limit but we haven't converged yet. Look
       # for a new upper limit
       optgoodidx   = optsearchidx;
       optsearchidx = iceil((optgoodidx + optbadidx)/2);
       #println("Good: $optgoodidx $optsearchidx $optbadidx $nfree $npacked");          
     end 
   end
 end # attempt loop

 packed;
end



function packpresents(presents, packmethod, splitmethod)
  # Pack presents using guillotine algorithm
  candidates = [idx for idx in 1:length(presents)];
  currentz   = 0;
  zmaplast   = zeros(Int,leveldim, leveldim);
  numpacked  = 0;
  numlevels  = 0;
  zadjust    = quantile([(p.zsize)::Int for p in presents],
                        [.1:.1:1.00]);     
  while (length(candidates) > 0)

    # Pack next set of presents in current shelf using
    # specified method.
    if (packmethod == :simple)
      packed = packSimple(presents, candidates, currentz, zadjust, splitmethod);
    else
      packed = packBinSearch(presents, candidates, currentz, zadjust, splitmethod);
    end
      
    # Do vertical compaction based on last zmap. First, check which transform
    # results in the best compaction.
    #println("  -- Compacting height");
    tup1 = tup2 = tup3 = tup4 = 0;
    maxup1 = maxup2 = maxup3 = maxup4 = abs(currentz);
    for pidx in sort(packed)
      p1  = presents[pidx];
      lz1 = minimum(@zmapget(zmaplast,
                              p1.xstart, p1.ystart,
                              p1.xsize,  p1.ysize));
      lz2 = minimum(@zmapget(zmaplast,
                              @flipcoord(p1.xstart, p1.xsize), p1.ystart,
                              p1.xsize, p1.ysize));
      lz3 = minimum(@zmapget(zmaplast,
                              p1.xstart, @flipcoord(p1.ystart, p1.ysize),
                              p1.xsize, p1.ysize));
      lz4 = minimum(@zmapget(zmaplast,
                              @flipcoord(p1.xstart, p1.xsize), @flipcoord(p1.ystart, p1.ysize),
                              p1.xsize, p1.ysize));

      maxup1 = min(lz1 - currentz, maxup1);
      maxup2 = min(lz2 - currentz, maxup2);
      maxup3 = min(lz3 - currentz, maxup3);
      maxup4 = min(lz4 - currentz, maxup4);      
                              
      tup1 += maxup1;
      tup2 += maxup2;
      tup3 += maxup3;
      tup4 += maxup4;      
    end

    upbest = maximum([tup1,tup2,tup3,tup4]);
    
    doflipx = false;
    doflipy = false;
    if     (tup1 == upbest)
      doflipx = false;
      doflipy = false;
    elseif (tup2 == upbest)
      doflipx = true;
    elseif (tup3 == upbest)
      doflipy = true;
    elseif (tup4 == upbest)
      doflipx = true;
      doflipy = true;
    end

    # NB - set zmap default value to currentz. If set to 0
    #      and the region doesn't get used in this round and
    #      the first present in the next round gets put underneath
    #      it, the present will get pushed to the top!
    zmap       = fill(currentz,leveldim, leveldim);
    maxup      = abs(currentz);
    packedarea = 0;
    for pidx in sort(packed)
      ptmp = presents[pidx];

      packedarea += ptmp.xsize * ptmp.ysize;
      
      if (doflipx)
        ptmp.xstart = @flipcoord(ptmp.xstart, ptmp.xsize);
      end
      if (doflipy)
        ptmp.ystart = @flipcoord(ptmp.ystart, ptmp.ysize);
      end
      
      lastz = minimum(zmaplast[ptmp.xstart:(ptmp.xstart + ptmp.xsize -1),
                               ptmp.ystart:(ptmp.ystart + ptmp.ysize -1)]);      
      maxup = min(lastz - currentz, maxup);

      # NB 
      #
      # Can't short circuit this loop once maxup == 0 since
      # this is now where the zmap entries get set. They can't
      # be set in the first loop because the translations may
      # leave behind stale entries in the zmap that will prevent
      # compaction.
      ptmp.zstart += maxup;
      zmap[ptmp.xstart:(ptmp.xstart+ptmp.xsize-1),
           ptmp.ystart:(ptmp.ystart+ptmp.ysize-1)] = ptmp.zstart - ptmp.zsize;
    end
    
    # Update z
    currentz = minimum(zmap);
    zmaplast = zmap;

    # Remove idxs of presents packed.
    #println("  -- Deleting packed presents");
    splice!(candidates, 1:length(packed));
      
    # Print level for debug and signs of life
    numpacked += length(packed);
    numlevels += 1;
    @printf("Level: %-8d  Packed: %.2f Waste: %.2f  Height: %d\n",
            numlevels,
            (numpacked / length(presents)),
            (1.0 - packedarea/levelarea),
            currentz);    
  end 
    
  # Fix Z dimension since we started at 1 and worked downwards.
  for p in presents
    p.zstart += abs(currentz);  
  end

  presents;
end



# ------------------------------------------------------------
# SUBMISSIONS
# ------------------------------------------------------------

function createsub(presents)
  # Create the submission array from the list of presents
  submission = zeros(Int, length(presents), 25);
  for i in 1:length(presents)
    submission[i,1] = presents[i].id;
    submission[i,[2,8,14,20]]   = presents[i].xstart;
    submission[i,[5,11,17,23]]  = presents[i].xstart + presents[i].xsize - 1;
    submission[i,[3,6,15,18]]   = presents[i].ystart;
    submission[i,[9,12,21,24]]  = presents[i].ystart + presents[i].ysize - 1;
    submission[i,[4,7,10,13]]   = presents[i].zstart;
    submission[i,[16,19,22,25]] = presents[i].zstart - presents[i].zsize + 1;  
  end

 submission;
end


function solsort(a,b)
 # NB - reversing Z sort to get packages at
 #      top of bag at begining of list since
 #      these should have the lowest present
 #      ids.
 if (a[2] > b[2])
  return true;
 elseif ((a[2] == b[2]) &&
         (a[1] < b[1]))
  return true;
 end
 return false;
end


function scoresub(submission)
 # Score the submission using the evaluation
 # formula
 sol  = hcat(submission[:,1],
             maximum(submission[:,[4,7,10,13,16,19,22,25]], 2));
 sol  = sortrows(sol, lt=solsort);

 maxz   = maximum(sol[:,2]);
 deltas = [abs(a-b) for (a,b) in zip(1:size(sol,1), sol[:,1])];
 dsum   = sum(deltas);
 
 println("Maxz: $maxz Delta $dsum");
 
 return 2*maxz + dsum;
end


function namesub(score)
  # Create a date and timestamped file name
  # for an official submission. Include score
  # to make it easier to identify submissions.
  string("submissions/sub_",
         strftime("%y.%m.%d_%H.%M", time()),
         "_", score, ".csv");
end

function savesub(submission, subfname)
  fsub = open(subfname, "w");
  write(fsub,string("PresentId,x1,y1,z1,x2,y2,z2,",
                    "x3,y3,z3,x4,y4,z4,x5,y5,z5,x6,",
                    "y6,z6,x7,y7,z7,x8,y8,z8\n"));
  writecsv(fsub,submission);
  close(fsub);
end


# ------------------------------------------------------------
# HARNESS
# ------------------------------------------------------------

function doit(presents, splitmethod)
  # Simple harness to pack presents, create submission,
  # and print score.
  packpresents(presents, splitmethod);
  submission = createsub(presents);
  score = scoresub(submission);
  println("Score is $score");
end


# ------------------------------------------------------------
# OLD
# ------------------------------------------------------------

function printlevel(level)
  # Function to print level
  print(map(v -> uppercase(hex(v)),level));
end


function compact(plist)
  # Compact list of presents into a
  # super-present.  
  cx = 0;
  cy = 0;
  ids = (); 
  for p in plist
    cx += presents[p,2];
    cy = max(cy, presents[p,3]);
  end
  (cx,cy)
end 


nothing;
