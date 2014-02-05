# ------------------------------------------------------------
# Julia solution to Kaggle 2013 Holiday Competition.
#
# http://www.kaggle.com/c/packing-santas-sleigh
#
# John Cardente
# jcardente@gmail.com
#
#
# This code contains experimental code developed during
# the competition. 
# ------------------------------------------------------------

#
# GEOMETRY STUFF
#

macro insidepoint(r, xpos, ypos)
quote
 ( ($r).xstart               <  $xpos) &&
 ((($r).xstart + ($r).xsize) >  $xpos) &&
 ( ($r).ystart               <  $ypos) &&
 ((($r).ystart + ($r).ysize) >  $ypos) 
end
end


# NB - Includes boundaries
macro containspoint(r, xpos, ypos)
quote
 ( ($r).xstart               <= $xpos) &&
 ((($r).xstart + ($r).xsize) >  $xpos) &&
 ( ($r).ystart               <= $ypos) &&
 ((($r).ystart + ($r).ysize) >  $ypos) 
end
end

macro rangeadjacent(astart, asize, bstart, bsize)
quote
(($(astart) == ($(bstart) + $(bsize))) ||
 ($(bstart) == ($(astart) + $(asize))))
end
end

macro rangeoverlap(astart, asize, bstart, bsize)
quote
((($(astart) >= $(bstart)) && ($(astart) < ($(bstart) + $(bsize)))) ||
 (($(bstart) >= $(astart)) && ($(bstart) < ($(astart) + $(asize)))))
end
end


# NB - doesn't include extremes
macro onrectedge(r, px, py)
quote
((($py == $(r).ystart)
 && ($px > $(r).xstart)
 && ($px < ($(r).xstart + $(r).xsize))) ||
(($py == ($(r).ystart + $(r).ysize))
 && ($px > $(r).xstart)
 && ($px < ($(r).xstart + $(r).xsize))) ||
(($px == $(r).xstart)
 && ($py > $(r).ystart)
 && ($py < ($(r).ystart + $(r).ysize))) ||
(($px == ($(r).xstart + $(r).xsize))
 && ($py > $(r).ystart)
 && ($py < ($(r).ystart + $(r).ysize))))
end
end


macro onhline(xstart, ystart, xend, yend, px, py)
quote
(($py == $ystart) && ($px >= $xstart) && ($px <= $xend))
end
end

macro onvline(xstart, ystart, xend, yend, px, py)
quote
(($px == $xstart) && ($py >= $ystart) && ($py <= $yend))
end
end



# Test if two line segments intersect
macro intersect(_Ex, _Ey, _Fx, _Fy, _Px, _Py, _Qx, _Qy)
quote
local Ex = $_Ex;
local Ey = $_Ey;
local Fx = $_Fx;
local Fy = $_Fy;
local Px = $_Px;
local Py = $_Py;
local Qx = $_Qx;
local Qy = $_Qy;
((sign((Fx - Ex) * (Py - Fy) - (Fy - Ey) * (Px - Fx)) !=
 sign((Fx - Ex) * (Qy - Fy) - (Fy - Ey) * (Qx - Fx)))
 &&
(sign((Qx - Px) * (Ey - Qy) - (Qy - Py) * (Ex - Qx)) !=
 sign((Qx - Px) * (Fy - Qy) - (Qy - Py) * (Fx - Qx))))
end
end



#
# FREESPACE REGION STUFF
#


# R1 top    to R2 left
macro topandleft(_R1, _R2)
quote
local R1 = $_R1;
local R2 = $_R2;
@intersect(R1.xstart, R1.ystart, R1.xstart + R1.xsize, R1.ystart,
           R2.xstart, R2.ystart, R2.xstart, R2.ystart + R2.ysize)

end
end
           
# R1 top    to R2 right
macro topandright(_R1, _R2)
quote
local R1 = $_R1;
local R2 = $_R2;
@intersect(R1.xstart, R1.ystart, R1.xstart + R1.xsize, R1.ystart,
           R2.xstart+R2.xsize, R2.ystart, R2.xstart+R2.xsize, R2.ystart + R2.ysize)
end
end
           
# R1 bottom to R2 left
macro bottomandleft(_R1, _R2)
quote
local R1 = $_R1;
local R2 = $_R2;
@intersect(R1.xstart, R1.ystart + R1.ysize, R1.xstart + R1.xsize, R1.ystart + R1.ysize,
           R2.xstart, R2.ystart, R2.xstart, R2.ystart + R2.ysize)
end
end

# R1 bottom to R2 right
macro bottomandright(_R1, _R2)
quote
local R1 = $_R1;
local R2 = $_R2;
@intersect(R1.xstart, R1.ystart+R1.ysize, R1.xstart + R1.xsize, R1.ystart + R1.ysize,
           R2.xstart+R2.xsize, R2.ystart, R2.xstart+R2.xsize, R2.ystart + R2.ysize)
end
end


# A is right of B
macro adjacentright(a,b)
quote
((($(a).xstart + $(a).xsize) == $(b).xstart) &&
 @rangeoverlap($(a).ystart, $(a).ysize, $(b).ystart, $(b).ysize))
end
end

macro adjacentleft(a,b)
quote
@adjacentright($b,$a)
end
end

# A is below B
macro adjacenttop(a,b)
quote
((($(b).ystart + $(b).ysize) == $(a).ystart) &&
 @rangeoverlap($(a).xstart, $(a).xsize, $(b).xstart, $(b).xsize))
end
end

macro adjacentbottom(a,b)
quote
@adjacenttop($b,$a)
end
end

macro adjacent(a,b)
quote
(@adjacentright($(a), $(b)) ||
 @adjacenttop($(a), $(b))   ||
 @adjacentleft($(a), $(b)) ||
 @adjacentbottom($(a), $(b)))
end
end 


function checkfreespace(r::Region, plist, currentz)
 # Check to see if a freespace overlaps with any
 # presents. This shouldn't happen.
 overlapidxs = Int[];
 for idx in 1:length(plist)
   p = plist[idx];
   if ((p.xstart < 1 ) ||
       (p.zstart != currentz))
     continue;
   end
   if (@containspoint(p,r.xstart, r.ystart) ||
       @containspoint(p,r.xstart + r.xsize - 1, r.ystart) ||
       @containspoint(p,r.xstart, r.ystart + r.ysize -1)  ||
       @containspoint(p,r.xstart + r.xsize - 1, r.ystart + r.ysize -1))
     push!(overlapidxs, idx);
   end
 end
 overlapidxs;
end


function inlist(r::Region, rlist)
 r1 = r;
 iscovered = false;
 for idx2 in 1:length(rlist)
   r2 = rlist[idx2];     
   if (@rectcovers(r2.xstart, r2.ystart, r2.xstart + r2.xsize, r2.ystart + r2.ysize,
                   r1.xstart, r1.ystart, r1.xstart + r1.xsize, r1.ystart + r1.ysize))
     iscovered = true;
     break;
   end
 end
 iscovered;
end

function removeredundant(rlist)
  newlist = copy(rlist);
  ridxs = findredundant(newlist);
  if (length(ridxs) > 0)
    newlist = newlist[filter(idx -> !(idx in ridxs),
                           1:length(rlist))];
  end              
 newlist;
end


function findadjacent(r, rlist)
 redidxs = Set();
 for idx in 1:length(rlist)
   if (@adjacent(r,rlist[idx]))
    push!(redidxs, idx);
   end
 end
 redidxs;
end


function mergeadjacent(rlistfull)
 # This routine takes a list of
 # regions and creates new regions
 # that overlap each pair of adjacent regions
 # The resulting list of overlapping rectangles
 # looks like the result of the overlapping
 # routine and can be used with the minimal
 # cover routine to fully reclaim the free
 # space with the least free regions.
 newrects   = Region[];
 addedrects = rlistfull;
 while (length(addedrects) > 0)
   # Added the latest batch of rectangles
   # and remove any duplicates.

   # Check if added are already in 
   if all(map( t -> inlist(t, newrects), addedrects))
     break;
   end
   
   append!(newrects, addedrects);
   newrects = removeredundant(newrects);
   if (length(newrects) == 1)
     break;
   end

   addedrects = Region[];   
   for ridx in 1:length(newrects)
     r     = newrects[ridx];
     rlist = newrects[filter(x -> x != ridx, 1:length(newrects))]; 

     # XXX - Fix this, don't need to compare each pair twice.
     
     # NB - there may be multiple rectangles adjacent on 
     #      each side!
     rrange = 1:length(rlist);
     top    = filter(x -> @adjacenttop(r, rlist[x]),   rrange);
     bottom = filter(x -> @adjacentbottom(r,rlist[x]), rrange);
     left   = filter(x -> @adjacentleft(r,rlist[x]),   rrange);
     right  = filter(x -> @adjacentright(r,rlist[x]),  rrange);
  
     # XXX - Very ugly series of if statements with similar code.
     #       Leaving this way due to deadline. Refactor if given  
     #       the chance.
     if (!isempty(top))
       #println("top");
       for rtidx in top
         rt     = rlist[rtidx];
         xstart = maximum([r.xstart, rt.xstart]);
         xend   = minimum([r.xstart + r.xsize, rt.xstart + rt.xsize]);
         ystart = rt.ystart;
         yend   = r.ystart + r.ysize;
         push!(addedrects, Region(xstart,
                                ystart,
                                xend - xstart,
                                yend - ystart));
       end
     end
  
     if (!isempty(bottom))
       #println("bottom");
       for rbidx in bottom
         rb     = rlist[rbidx];
         xstart = maximum([r.xstart, rb.xstart]);
         xend   = minimum([r.xstart + r.xsize, rb.xstart + rb.xsize]);
         ystart = r.ystart;
         yend   = rb.ystart + rb.ysize;
         push!(addedrects, Region(xstart,
                                ystart,
                                xend - xstart,
                                yend - ystart));
       end
     end
    
     if (!isempty(right))
       #println("right");
       for rridx in right
         rr     = rlist[rridx];
         xstart = r.xstart;
         xend   = rr.xstart + rr.xsize;
         ystart = maximum([r.ystart, rr.ystart]);
         yend   = minimum([(r.ystart  + r.ysize),
                           (rr.ystart + rr.ysize)]);
         push!(addedrects, Region(xstart,
                                ystart,
                                xend - xstart,
                                yend - ystart));
       end
     end
  
     if (!isempty(left))
       #println("left");
       for rlidx in left
         rl     = rlist[rlidx];
         xstart = rl.xstart;
         xend   = r.xstart + r.xsize;
         ystart = maximum([r.ystart, rl.ystart]);
         yend   = minimum([(r.ystart  + r.ysize),
                           (rl.ystart + rl.ysize)]);
         push!(addedrects, Region(xstart,
                                ystart,
                                xend - xstart,
                                yend - ystart));
       end  
     end
   end

 end # while addedrects
 
 newrects;
end


#
# DEPTHWISE ALGORITHM
#
# The following code implements an algorithm that
# - Tracks the z-depth at which space is freed
# - Returns that freespace when the appropriate
#   depth is reached.
# - Merges the new freespace with any adjacent
#   freespace to create larger freespace regions.
#
# This code included an implementation of a minimal
# rectangle cover algorithm to determine the largest
# freespace regions created by a set of adjacent freespaces.
#
# This algorithm worked but didn't perform as well as
# the shelf oriented algorithm.
#

# Find all intersecting edges between to regions
function concaveverts(r1,r2)
  verts = Set();

  # NB - don't include intersects at "opposite"
  #      extremes

  # XXX - "top" is actually the lowest Y.
  #       Fix at some point. Shouldn't matter
  #       if we stay consistent.
  if (@topandleft(r1,r2) &&
      (r1.ystart > r2.ystart) &&
      (r1.ystart < (r2.ystart + r2.ysize)) &&
      (r2.xstart > r1.xstart) &&
      (r2.xstart < (r1.xstart + r1.xsize)))
    #println("r1r2 topandleft");
    push!(verts,(r2.xstart, r1.ystart));
  end
  if (@topandright(r1,r2) &&
      (r1.ystart > r2.ystart) &&
      (r1.ystart < (r2.ystart + r2.ysize)) &&
      ((r2.xstart+r2.xsize) > r1.xstart) &&
      ((r2.xstart+r2.xsize) < (r1.xstart + r1.xsize)))
    #println("r1r2 topandright");
    push!(verts,(r2.xstart+r2.xsize, r1.ystart));
  end
  if (@bottomandleft(r1,r2) &&
      ((r1.ystart+r1.ysize) > r2.ystart) &&
      ((r1.ystart+r1.ysize) < (r2.ystart + r2.ysize)) &&
      (r2.xstart > r1.xstart) &&
      (r2.xstart < (r1.xstart + r1.xsize)))
    #println("r1r2 bottomandleft");
    push!(verts,(r2.xstart, r1.ystart+r1.ysize));
  end
  if (@bottomandright(r1,r2) &&
      ((r1.ystart +r1.ysize) > r2.ystart) &&
      ((r1.ystart + r1.ysize) < (r2.ystart + r2.ysize)) &&
      ((r2.xstart+r2.xsize) > r1.xstart) &&
      ((r2.xstart+r2.xsize) < (r1.xstart + r1.xsize)))
    #println("r1r2 bottomandright");
    push!(verts,(r2.xstart + r2.xsize, r1.ystart+r1.ysize));
  end

  # NB - reverse tests
  if (@topandleft(r2,r1) &&
      (r2.ystart > r1.ystart) &&
      (r2.ystart < (r1.ystart + r1.ysize)) &&
      (r1.xstart > r2.xstart) &&
      (r1.xstart < (r2.xstart + r2.xsize)))
    #println("r1r2 topandleft");
    push!(verts,(r1.xstart, r2.ystart));
  end
  if (@topandright(r2,r1) &&
      (r2.ystart > r1.ystart) &&
      (r2.ystart < (r1.ystart + r1.ysize)) &&
      ((r1.xstart+r1.xsize) > r2.xstart) &&
      ((r1.xstart+r1.xsize) < (r2.xstart + r2.xsize)))
    #println("r2r1 topandright");
    push!(verts,(r1.xstart + r1.xsize, r2.ystart));
  end
  if (@bottomandleft(r2,r1) &&
      ((r2.ystart+r2.ysize) > r1.ystart) &&
      ((r2.ystart+r2.ysize) < (r1.ystart + r1.ysize)) &&
      (r1.xstart > r2.xstart) &&
      (r1.xstart < (r2.xstart + r2.xsize)))
    #println("r2r1 bottomandleft");
    push!(verts, (r1.xstart, r2.ystart + r2.ysize));
  end 
  if (@bottomandright(r2,r1)  &&
      ((r2.ystart+r2.ysize) > r1.ystart) &&
      ((r2.ystart+r2.ysize) < (r1.ystart + r1.ysize)) &&
      ((r1.xstart+r1.xsize) > r2.xstart) &&
      ((r1.xstart+r1.xsize) < (r2.xstart + r2.xsize)))
    #println("r2r1 bottomandright");
    push!(verts, (r1.xstart + r1.xsize, r2.ystart + r2.ysize));
  end
  
  verts;
end



function getallconcaveverts(rlist)
  verts = Set();
  for idx1 in 1:(length(rlist)-1)
    for idx2 in (idx1+1):length(rlist)
      union!(verts, concaveverts(rlist[idx1], rlist[idx2]));
    end
  end

  # NB - remove concave vertices inside regions since
  #      they are not on the edge of the resulting
  #      polygon.
  for idx1 in 1:length(rlist)
    filter!( p -> !(@insidepoint(rlist[idx1], p[1], p[2])), verts);
  end
  
  verts;
end


function getallconvexverts(rlist)
  verts = Set();
  for idx1 in 1:length(rlist)
    thisverts = [(rlist[idx1].xstart, rlist[idx1].ystart),
                 (rlist[idx1].xstart, rlist[idx1].ystart + rlist[idx1].ysize),
                 (rlist[idx1].xstart + rlist[idx1].xsize, rlist[idx1].ystart),
                 (rlist[idx1].xstart + rlist[idx1].xsize,
                  rlist[idx1].ystart + rlist[idx1].ysize)];
    for idx2 in 1:length(rlist)
      if (idx1 == idx2)
        continue;
      end

      # Remove this point if it is on the edge or inside
      # of another region. 
      filter!( p -> !(@insidepoint(rlist[idx2], p[1], p[2])), thisverts);
      filter!( p -> !(@onrectedge(rlist[idx2], p[1], p[2])), thisverts);
    end
    union!(verts, thisverts);
  end
  
  verts;
end


function getallverts(rlist)
  verts = Tuple[];
  for idx1 in 1:length(rlist)
    thisverts = [(rlist[idx1].xstart, rlist[idx1].ystart),
                 (rlist[idx1].xstart, rlist[idx1].ystart + rlist[idx1].ysize),
                 (rlist[idx1].xstart + rlist[idx1].xsize, rlist[idx1].ystart),
                 (rlist[idx1].xstart + rlist[idx1].xsize,
                  rlist[idx1].ystart + rlist[idx1].ysize)];
    append!(verts, thisverts);
  end
 verts;
end





function mincoverrects(rlist)
 # Given a list of rects, find the minimal
 # cover of rectangles. This is based on the algorithm
 # from,
 #
 # Decomposing Rectilinear Figures into Rectangles.
 # Ritu Chadha and Donald C. S. Allison
 # http://eprints.cs.vt.edu/archive/00000102/01/TR-88-17.pdf

 # NB - using the orientation from the paper in this routine.
 #      Up is higher y. Down is lower y. Right is higher X.
 #      left is lower X. Other routines in this file may
 #      use the opposite orientation for up/down.
 #
 # XXX - make up/down consistent across all routines. 
 
 
 # NB - It is assumed that rlist is a set of regions
 #      where each overlaps with at least one other.
 #      Hence, we can cheat a bit by getting the
 #      convex and concave vertices directly.
 vconvex  = getallconvexverts(rlist);
 vconcave = getallconcaveverts(rlist);

 # Create Hvertices list 
 Hvertices = [v for v in union(vconvex, vconcave)];
 sort!(Hvertices, lt = (a,b) -> (a[2] < b[2]) ||
       ((a[2] == b[2]) && (a[1] < b[1])));

 # Determine horizontal neighbors and edges
 Hneighbors = Dict();
 HElist = Tuple[];
 for hvidx in 1:(length(Hvertices)-1)
  hv1 = Hvertices[hvidx];
  if (!(haskey(Hneighbors, hv1)))
    hv2 = Hvertices[(hvidx+1)];
    @assert(!(haskey(Hneighbors,hv2)));
    Hneighbors[hv1] = (:left, hv2);
    Hneighbors[hv2] = (:right, hv1);
    push!(HElist, (hv1, hv2));
  end
 end
 @assert(all([haskey(Hneighbors, v) for v in Hvertices]));

 # Determine vertical neighbors and edges
 Vneighbors = Dict();
 VElist = Tuple[];
 for vvidx in 1:(length(Hvertices)-1)
  vv1 = Hvertices[vvidx];
  vv2 = 0;   # scope fudge
  if (!(haskey(Vneighbors,vv1)))
    for vvidx2 in (vvidx+1):length(Hvertices)
      vv2 = Hvertices[vvidx2];
      if (vv2[1] == vv1[1])
        break;
      end
    end
    @assert((vv2[1] == vv1[1]));
    @assert(!(haskey(Vneighbors, vv2 )));
    Vneighbors[vv1] = (:bottom, vv2);
    Vneighbors[vv2] = (:top, vv1);
    push!(VElist, (vv1, vv2));
  end
 end
 @assert(all([haskey(Vneighbors, v) for v in Hvertices]));

 # Get contour
 EXT = Tuple[];
 push!(EXT, Hvertices[1]);
 EXTvisited = Set();
 dirnext = :horiz;
 while true
   extlast = last(EXT);
   push!(EXTvisited, extlast);
   if (dirnext == :horiz)
      vnext   = Hneighbors[extlast][2];
      dirnext = :vert
   else
      vnext   = Vneighbors[extlast][2];
      dirnext = :horiz
   end

   if !(vnext in EXTvisited)
     push!(EXT,vnext);
   else
     break;
   end   
 end

 # Determine convex and concave vertices
 # Use from original freespaces? 
 #
 # XXX - TODO

 
 # Create sorted list of horzontal vertices
 Vvertices = copy(Hvertices);
 sort!(Vvertices, lt = (a,b) -> ((a[1] < b[1]) ||
                                 ((a[1] == b[1]) && (a[2] < b[2]))))

 # Determine left and right edges
 dirnext = :horiz;
 RElist = Tuple[];
 LElist = Tuple[];
 for eidx in 1:length(EXT)
   ev = EXT[eidx];
   if (dirnext == :horiz)
      dirnext = :vert
   else
      vnext   = Vneighbors[ev];
      if (vnext[1] == :bottom)
        push!(RElist, (ev, vnext[2]));
      else
        push!(LElist, (vnext[2], ev));      
      end
      dirnext = :horiz
   end
 end

 # Create lines from concave vertexes to
 # boundaries.
 HCOMB = Tuple[];
 VCOMB = Tuple[];
 for cv in vconcave
   # Check to see if a horizontal line
   # already exists
   hlexists = false;
   for hl in HCOMB
    if (@onhline(hl[1][1], hl[1][2], hl[2][1], hl[2][2], cv[1], cv[2]))
      hlexists = true;
      break;
    end
   end

   if (!hlexists)
     # Determine direction to extend line
     if (Hneighbors[cv][1] == :left)
       # Extend line to the left. Find the left
       # edge that is closest to this point
       ledist    = 2*leveldim;
       leclosest = ();
       for le in LElist
         if (@intersect(le[1][1]-1, cv[2], cv[1], cv[2],
                        le[1][1], le[1][2], le[2][1], le[2][2]))
           xdist = cv[1] - le[1][1];
           if ((xdist > 0) && (xdist < ledist))
             leclosest = le;
             ledist    = xdist;
           end
         end
       end
       push!(HCOMB, ((leclosest[1][1], cv[2]), (cv[1], cv[2])));     

     else
       # Extend line to the right. Find the right
       # edge that is the closest to this point
       redist    = 2*leveldim;
       reclosest = ();
       for re in RElist
         if (@intersect(cv[1], cv[2], re[1][1]+1, cv[2],
                        re[1][1], re[1][2], re[2][1], re[2][2]))
           xdist = re[1][1] - cv[1];
           if ((xdist > 0) && (xdist < redist))
             reclosest = re;
             redist    = xdist;
           end
         end
       end
       
       # Add edge to HCOMB
       push!(HCOMB, ((cv[1],cv[2]), (reclosest[1][1], cv[2])));          
     end
   end
   
   # Check to see if a vertical line
   # already exists
   vlexists = false;
   for vl in VCOMB
    if (@onvline(vl[1][1], vl[1][2], vl[2][1], vl[2][2], cv[1], cv[2]))
      vlexists = true;
      break;
    end
   end

   if (!vlexists)
     # Determine direction to extend line
     if (Vneighbors[cv][1] == :top) # XXXXX
       # Extend upward
       tedist    = 2*leveldim;
       teclosest = ();
       for te in HElist
         if (@intersect(te[1][1], te[1][2], te[2][1], te[2][2],
                        cv[1], te[1][2]+1, cv[1], cv[2]))                        
           ydist = te[1][2] - cv[2];
           if ((ydist > 0) && (ydist < tedist))
             teclosest = te;
             tedist    = ydist;
           end
         end
       end
       push!(VCOMB, ((cv[1], cv[2]), (cv[1], teclosest[1][2])));     
       
     else
       # Extend downward
       bedist    = 2*leveldim;
       beclosest = ();
       for be in HElist
         if (@intersect(be[1][1], be[1][2], be[2][1], be[2][2],
                        cv[1], cv[2], cv[1], be[1][2]-1))
           ydist = cv[2] - be[1][2];
           if ((ydist > 0) && (ydist < bedist))
             beclosest = be;
             bedist    = ydist;
           end
         end
       end
       push!(VCOMB, ((cv[1], beclosest[1][2]), (cv[1], cv[2])));            
     end
   end    
 end


 # Append edgelists and sort
 append!(HCOMB, HElist);
 append!(VCOMB, LElist);
 LVCOMB = copy(VCOMB);
 append!(VCOMB, RElist);
 sort!(HCOMB, lt = (a,b) -> ((a[1][2] < b[1][2]) ||
                             ((a[1][2] == b[1][2]) && (a[1][1] < b[1][1]))));
 sort!(VCOMB, lt = (a,b) -> ((a[1][1] < b[1][1]) ||
                             ((a[1][1] == b[1][1]) && (a[1][2] < b[1][2]))));

 # Create list of basic rectangles
 BASICS = Tuple[];
 for le in LElist
   # Extend upwards and downwards
   tedist    = 2*leveldim;
   teclosest = ();
   cv = le[2];
   #println(" ** Checking le $le");   
   for te in HElist
     #println("te -- $te");
     # NB - "upward" here means toward a higher y value. 
     # NB - Substract extended top point by 1 just in case
     #      point is on the line.
     if (@intersect(te[1][1], te[1][2], te[2][1], te[2][2],
                    cv[1], cv[2], cv[1], te[1][2] +1) &&
         te[2][1] > cv[1])
       ydist = te[1][2] - cv[2]; # up is higher y
       #println("  isgood: ydist($ydist) tedist($tedist)");
       if ((ydist >= 0) && (ydist < tedist))
         teclosest = te;
         tedist    = ydist;
       end
     end
   end
   @assert(teclosest != ());
   
   bedist    = 2*leveldim;
   beclosest = ();
   cv = le[1];   
   for be in HElist
     #println("be -- $be");
     # NB - Add extended bottom point by 1 just in case
     #      point is on the line.
     if (@intersect(be[1][1], be[1][2], be[2][1], be[2][2],
                    cv[1], be[1][2] -1, cv[1], cv[2]) &&
         (be[2][1] > cv[1]))
       ydist = cv[2] - be[1][2];
       #println("  isgood: ydist($ydist) bedist($bedist)");              
       if ((ydist >= 0) && (ydist < bedist))
         beclosest = be;
         bedist    = ydist;
       end
     end
   end
   @assert(beclosest != ());
     
   # Create list of extended line segments
   # and loop over them
   lplist = Tuple[];
   push!( lplist, ((le[1][1], beclosest[1][2]),
                   (le[1][1], teclosest[1][2])));
   lastdist = 0;
   while (length(lplist) > 0)
      lp = shift!(lplist);
      #println(" ** lp $lp");
      # Find closest right edge
      redist    = 2*leveldim;
      reclosest = ();
      cv = lp[1];
      for re in RElist
        #println("re -- $re");
        # NB - edge can be closest at any point along the line!!
        if (@rangeoverlap(lp[1][2], lp[2][2] - lp[1][2],
                          re[1][2], re[2][2] - re[1][2]))
          xdist = re[1][1] - cv[1];
          #println("  isgood xdist $xdist  redist $redist");
          if ((xdist > 0) && (xdist < redist))
            reclosest = re;
            redist    = xdist;
          end
        end
      end
      @assert(reclosest != ());
      
      # Create rectangle and put on BASIC list.
      # Don't add a duplicate BASIC if we've already
      # processed an edge at this distance.      
      if (redist > lastdist)
        # NB - the BASIC box is the height of this segment
        #      with a right edge at reclosest's X.
        push!(BASICS, ((lp[1][1],        lp[1][2]),
                       (reclosest[1][1], lp[2][2])));
      end
      lastdist = redist;

      # Subtract projection, add remnants to
      # list
      #bxstart = lp[1][1];
      #bxend   = reclosest[1][1];
      bystart = maximum([lp[1][2], reclosest[1][2]]);
      byend   = minimum([lp[2][2], reclosest[2][2]]);

      if (lp[1][2] < bystart)
        push!(lplist, ((lp[1][1], lp[1][2]),
                       (lp[1][1], bystart)));
      end
      if (byend < lp[2][2])
        push!(lplist, ((lp[1][1], byend),
                       (lp[2][1], lp[2][2])));
      end
   end
 end

 # Create list of subrectangles
 SUBRECT = Tuple[];
 for le in LVCOMB
   lplist = Tuple[];
   push!( lplist, le);
   while (length(lplist) > 0)
     lp = shift!(lplist);
     #println("** $lp");
     # Find first horizontal line that
     # - Intersects with L at a point p
     # - p is not the lower extremity of L
     # - p is not the right extremity of H
     tedist = 2*leveldim;
     teclosest = ();
     for te in HCOMB
       #println("te -- $te");
       if (@intersect(te[1][1], te[1][2], te[2][1], te[2][2],
                      lp[1][1], lp[1][2], lp[2][1], lp[2][2]+1) &&
           (te[1][2] > lp[1][2]) &&
           (lp[1][1] < te[2][1]))
         ydist = te[1][2] - lp[1][2];
         #println("  isgood: ydist($ydist) tedist($tedist)");         
         if ((ydist > 0) && (ydist < tedist))
           teclosest = te;
           tedist    = ydist;
         end
       end
     end
     @assert(teclosest != ());
  
     # Find nearest right edge
     redist    = 2*leveldim;
     reclosest = ();
     for re in VCOMB
       # NB - edge can be closest at any point along the line!!
       if (@rangeoverlap(lp[1][2], lp[2][2] - lp[1][2],
                         re[1][2], re[2][2] - re[1][2]) &&
           (lp[1][1] < re[1][1]))
         xdist = re[1][1] - lp[1][1];
         if ((xdist > 0) && (xdist < redist))
           reclosest = re;
           redist    = xdist;
         end
       end
     end
     @assert(reclosest != ());
  
     # Create subrect
     push!(SUBRECT, ((lp[1][1], lp[1][2]),
                     (reclosest[1][1],teclosest[1][2])));
     
     # Subtract projection, add remnants to
     # list
     bystart = lp[1][2];
     byend   = teclosest[1][2];        
     if (lp[1][2] < bystart)
       push!(lplist, ((lp[1][1], lp[1][2]),
                      (lp[1][1], bystart)));
     end
     if (byend < lp[2][2])
       push!(lplist, ((lp[1][1], byend),
                      (lp[2][1], lp[2][2])));
     end
   end   
 end

 # Create cover chart
 covermap = zeros(Int8, length(BASICS), length(SUBRECT));
 for bidx = 1:length(BASICS)
   for sidx = 1:length(SUBRECT)
     br = BASICS[bidx];
     sr = SUBRECT[sidx];
     if (@rectcovers(br[1][1], br[1][2], br[2][1], br[2][2],
                       sr[1][1], sr[1][2], sr[2][1], sr[2][2]))
        covermap[bidx, sidx] = 1;
     end
   end
 end

 # Find BASICS that solely cover subrects. These must
 # be included in the minimal cover and remove them.
 csums = sum(covermap, 1);
 onecover = filter( x-> csums[x]==1, 1:length(csums));
 minrectidxs = Set();
 colsrm = Set();
 for sidx in onecover
   # NB - first is just a fudge to convert to an int
   bidx = first(findin(covermap[:,sidx] .== 1,[true]));
   push!(minrectidxs, bidx);
   union!(colsrm, findin(covermap[bidx,:] .> 0, [true]));
 end
 covermap[filter(x-> (x in minrectidxs), 1:size(covermap,1)),:] = 0;
 covermap[:,filter(x-> (x in colsrm), 1:size(covermap,2))] = 0;

 # Remove dominated rows and columns
 domrows = Set(); 
 for bidx1 = 1:(size(covermap,1)-1)
    if (sum(covermap[bidx1,:]) ==0)
      continue;
    end
    for bidx2 = (bidx1+1):size(covermap,1)
      if (all(covermap[bidx1,:] .== covermap[bidx2,:]))
        push!(domrows, bidx2);
      end
    end
 end
 covermap[filter(x-> (x in domrows), 1:size(covermap,1)),:] = 0;

 domcols = Set(); 
 for sidx1 = 1:(size(covermap,2)-1)
    if (sum(covermap[:,sidx1]) ==0)
      continue;
    end
    for sidx2 = (sidx1+1):size(covermap,2)
      if (all(covermap[:,sidx1] .== covermap[:,sidx2]))
        push!(domcols, sidx2);
      end
    end
 end
 covermap[:,filter(x-> (x in domcols), 1:size(covermap,2))] = 0;

 # NB - Skipping the cyclic resolution part of the algorithm.
 #      It's OK if we don't get the absolute minimal cover.

 # Any row with a non-zero column is a basic rectangle
 # in the minimum cover
 union!(minrectidxs,
        filter(x-> (sum(covermap[x,:]) >0), 1:size(covermap,1)));
        
 # Convert minimal cover BASIC rectangles to Regions
 newrects = Region[];
 for bidx in minrectidxs
   br = BASICS[bidx];
     push!(newrects,
           Region(br[1][1],
                  br[1][2],
                  br[2][1] - br[1][1],
                  br[2][2] - br[1][2]));
 end
 
 newrects;
end




function packpresentsdepthwise(presents, splitmethod)
  freespaces = [Region(1,1,leveldim,leveldim, 0)];
  freeQueue  = Region[];  
  currentz   = 0;
  maxz       = 0;
  npresents  = length(presents);

  zadjust = quantile([(p.zsize)::Int for p in presents],
                     [.1:.1:1.00]);   
  for pidx in 1:npresents
    p = presents[pidx];
    
    # Find freespace for present. Add more freespaces
    # from queue until success. 
    ridx = findregion(p, freespaces, zadjust);
    while (ridx == 0)
    
      # Couldn't find a freespace.     
      # XXX - try defragging first
      
      # Defragging didn't work, are there any freespaces
      # on the freeQueue to add back?
      if (isempty(freeQueue))
        # If we get here, it means none of the freespaces are
        # big enough. Only option is to go to maximum Z and
        # create a new big free space.
        #
        # NB - clear out freespace list since, by definition,
        #      all current freespaces will overlap.       
        freeQueue = [Region(1,1,leveldim,leveldim, maxz)];
        freespaces = Region[];

        println(" !!!! Bring down the hammer!");
      end

      
      # Pull next batch of freespaces off the queue.
      # 
      #  NB - remember zstarts are negative ints
      #       during packing
      sort!(freeQueue, lt = (a,b) -> a.zstart > b.zstart);      
      currentz = freeQueue[1].zstart;
      while ((!(isempty(freeQueue))) &&
             (freeQueue[1].zstart == currentz))

        # Freespaces added back can never overlap an existing
        # freespace. However, they can be adjacent to existing
        # freespaces. They need to be merged in order to recover
        # the maximum amount of freespace.
        newlist = Region[];
        rnew    = shift!(freeQueue);
        adjidxs = findadjacent(rnew, freespaces);
        if (length(adjidxs) > 0)
           adjacents = freespaces[filter(idx -> (idx in adjidxs),
                                         1:length(freespaces))];
           push!(adjacents, rnew);
           #println("Starting mincover");
           #println("rn: $rnew");
           #println("adj: $adjacents");

           adjoverlaps = mergeadjacent(adjacents);
           @assert(length(adjoverlaps) > 0);
           #println("ao:  $adjoverlaps");
           covers = mincoverrects(adjoverlaps);
           #println(" --end");

           # XXX - remove adjacents and replace with new covers
           #       This actually lowered the score. Need to figure out
           #       why.
           #freespaces = freespaces[filter(idx -> !(idx in adjidxs),
           #                               1:length(freespaces))];
           append!(newlist, covers );
        else
          push!(newlist, rnew);        
        end
        append!(freespaces, newlist);        
      end
      ridx = findregion(p, freespaces, zadjust);
    end

    # Pack present and update maxz
    placepresent!(freespaces[ridx], p, currentz);
    maxz = min(maxz, currentz - p.zsize);
    
    # Maximally split the freespace
    roverlaps = findoverlapping(p, freespaces);
    @assert(length(roverlaps) >= 1);
    newregions = Region[];
    for roidx in roverlaps            
      # Compute new free space
      append!(newregions, splitfreespace(freespaces[roidx], p, splitmethod));
    end

    # Remove old free space and add new
    freespaces = freespaces[filter(idx -> !(idx in roverlaps),
                            1:length(freespaces))]; 
    prepend!(freespaces, newregions);

    # Add future freespace to queue
    push!(freeQueue,
          Region(p.xstart, p.ystart,
                 p.xsize, p.ysize,
                 p.zstart - p.zsize));


    # XXX - Garbage collection only useful if we can
    #       deal with large patches connected by
    #       overlapping  regions. Such a collection
    #       may contain holes. Need a way to deal with
    #       that.
    #
    ## if ((pidx % 100) == 0)
    ##   # Time for a little freespace cleanup.
    ##   # Walk the freespace. Get overlaps
    ##   # and compute minimal cover.
    ##   newfreespaces = Region[];
    ##   for fs in freespaces
    ##     roverlaps = findoverlapping(p, freespaces);
    ##     if (length(roverlaps) > 0)
    ##        rovers = Region[];
    ##        append!(rovers,freespaces[roverlaps]);
    ##        push!(rovers, fs);
    ##        rcovers = mincoverrects(adjoverlaps);
    ##        append!(newfreespaces, rcovers);
    ##     else
    ##       push!(newfreespaces,fs);
    ##     end
    ##   end
    ##   @printf("Cleanup: %d to %d\n", length(freespaces), length(newfreespaces));
    ##   freespaces = newfreespaces;
    ## end

    # Remove duplicate freespaces
    #
    # NB - doing this every time seems to be OK
    #      and reduces runtime.
    redidxs = findredundant(freespaces);
    if (length(redidxs) > 0)
      freespaces = freespaces[filter(idx -> !(idx in redidxs),
                              1:length(freespaces))];
    end
                 
    if ((pidx % 1000) == 0)
      @printf("Packed: %.2f  LenFree: %d\n", pidx/npresents, length(freespaces));       
    end
  end

  # Fix Z dimension since we started at 1 and worked downwards.
  for p in presents
    p.zstart += abs(maxz);  
  end

  presents;
end


#
# DEBUG CODE
#

function checkpresents(plist)
 badidxs = Set();
 for idx1 in 1:length(plist)
  p1 = plist[idx1];
  if (p1.xstart < 1)
    continue;
  end
  for idx2 in 1:length(plist)
     p2 = plist[idx2];     
     if ((idx1 == idx2) ||
         (p2.xstart < 1))
       continue;
     end     

     if (@overlap3d(p2,p1))
       println("Present $idx2 contains $idx1");
       push!(badidxs, idx1);
       break;
     end
   end
 end
 badidxs;
end



