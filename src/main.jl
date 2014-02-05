# ------------------------------------------------------------
# Julia solution to Kaggle 2013 Holiday Competition.
#
# http://www.kaggle.com/c/packing-santas-sleigh
#
# John Cardente
# jcardente@gmail.com
#
# ------------------------------------------------------------

include("src/packPresents.jl");

# Read presents file. Create array of Present composite types.
inputfile = "data/presents.csv";
presents = loadpresents(inputfile);
resetpresents(presents);

# Pack the presents
#
# Packing options:
# :simple    - pack in present order
# :binsearch - pack using a binary search in area order
#
# Free place splitting options:
# SplitGuillotine() - Use a simple guillotine cut
# SplitMaximal()    - Split freespace in maximum rectangles.
packpresents(presents, :binsearch, SplitMaximal());

# Create the submission array, score it,
# and write a date/time stamped file
submission = createsub(presents);
score = scoresub(submission);
println("Score is $score");

savesub(submission, namesub(score));



