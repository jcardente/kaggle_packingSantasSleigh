// ---------------------------------------------------
// packagesViewer.pde
//
// A processing application to visualize solutions to
// the Kaggle Packing Santa's Sleigh challenge.
//
// https://www.kaggle.com/c/packing-santas-sleigh
//
// John Cardente
// December, 2013
//
// ---------------------------------------------------

import peasy.*;
import controlP5.*;


// ---------------------------------------------------
// SLEIGH
//
// Represents sleigh. Modeled as a flat plane
// with the provided dimensions.


class Sleigh {
  int spacing = 20;
  int dim;

  Sleigh(int _dim) {
    dim     = _dim;
  } 

  void draw() { 
    pushMatrix();
    pushStyle();

    if (isWireframe) {
      stroke(96, 189, 104, 100); 
      noFill();
      for (int i = 0; i <= dim; i += spacing) {
        line(i, 0, 0, i, 0, dim);
        line(0, 0, i, dim, 0, i);
      }
    } 
    else {
      noStroke();
      fill(96, 189, 104, 100);
      translate(dim/2, 0, dim/ 2);
      box(dim, 1, dim);
    }

    popStyle();
    popMatrix();
  }
}


// ---------------------------------------------------
// PRESENT
//
// Represents an individual present. 

class Present {
  int id; // Present ID
  int cx; // Corner X
  int cy; // Corner Y
  int cz; // Corver Z
  int lx; // Length X
  int ly; // Length Y
  int lz; // Length Z

  Present(int _id, 
          int _cx, int _cy, int _cz, 
          int _lx, int _ly, int _lz) {
    id = _id;
    cx = _cx;
    cy = _cy;
    cz = _cz;
    lx = _lx;
    ly = _ly;
    lz = _lz;
  }

  void draw() {
    pushStyle();
    
    if (isWireframe) {
      stroke(178, 145, 47, opacity); 
      noFill();
    } 
    else {
      noStroke();
      fill(178, 145, 47, opacity); 
    }

    // NB - note that the Y and Z axis are switched
    //      to translate between the coordinate systems
    //      of the problem and Processing. 
    pushMatrix();
    translate(cx + lx/2, -1 * (cz + lz/2), cy+ly/2);
    box(lx, lz, ly);
    popMatrix();
    popStyle();
  }
}


// -------------------------------------------------
// INTERACTION AND UI

void keyPressed() {
  if (key == CODED) {
    if (keyCode == UP) {
      camHeight += 10;
      Slider s   = (Slider) cp5.getController("height");
      s.setValue(camHeight);      
      
    } else if (keyCode == DOWN) {
      camHeight -= 10;
      Slider s   = (Slider) cp5.getController("height");
      s.setValue(camHeight);           
      
    } else if (keyCode == RIGHT) {
      cam.pan(10,0); 
      
    } else if (keyCode == LEFT) {
      cam.pan(-10,0);
    }
  }
}

void OpenFile (int _value) {
   selectInput("Select a file to process:", "fileSelected");
}

void fileSelected(File selection) {
  
  if (selection == null) {
   return; 
  }
  
  fileLoaded = false;
  Slider s   = (Slider) cp5.getController("height");
  s.setVisible(false);
  s   = (Slider) cp5.getController("opacity");
  s.setVisible(false);

  table    = loadTable(selection.getAbsolutePath(), "header");
  presents = new Present[table.getRowCount()];
  int pnum = 0;
  for (TableRow row : table.rows()) {
    int id = row.getInt("PresentId");
    
    int[] dims = new int[24];
    int ncols = row.getColumnCount();
    for (int i = 1; i < ncols;  i++) {
      dims[i-1] = row.getInt(i);
    }

    int[] Xs = {dims[0],  dims[3],  dims[6],  dims[9],  
                dims[12], dims[15], dims[18], dims[21]};
    int[] Ys = {dims[1],  dims[4],  dims[7],  dims[10],  
                dims[13], dims[16], dims[19], dims[22]};
    int[] Zs = {dims[2],  dims[5],  dims[8],  dims[11],  
                dims[14], dims[17], dims[20], dims[23]};

    int minX = min(Xs);
    int maxX = max(Xs);
    int minY = min(Ys);
    int maxY = max(Ys);
    int minZ = min(Zs);
    int maxZ = max(Zs);
    
    bagHeight = max(maxZ, bagHeight);
    
    presents[pnum] = new Present(id, minX, minY, minZ,
                                 maxX-minX, maxY-minY, maxZ-minZ);    
    pnum++;
  }

  fileLoaded = true;

  s   = (Slider) cp5.getController("height");
  s.setRange(0,bagHeight);
  s.setVisible(true);

  s   = (Slider) cp5.getController("opacity");
  s.setVisible(true);

  Textlabel tl = (Textlabel) cp5.getController("currentFile");
  tl.setText(selection.getName());
  
}


void wireframe(float[] a) {  
  if (a[0] == 0) {
    isWireframe = false;
  } else if (a[0] == 1) {
    isWireframe = true; 
  }
}

void height(float h) {  
  camHeight = floor(h);
}


void opacity(float o) {
 opacity = o; 
}


// -------------------------------------------------
// MAIN ROUTINES

PeasyCam  cam;
ControlP5 cp5;
Table     table;
Sleigh    sleigh;
Present[] presents;
boolean   fileLoaded  = false;
boolean   isWireframe = false;
int       bagHeight   = 0;
int       camHeight   = 100;
float     opacity     = 100;

void setup() {

  size(750, 750, P3D);
  background(#EEEEEE);

  cam = new PeasyCam(this, 1500);
  cam.setMinimumDistance(5);
  cam.setMaximumDistance(10000);
  cam.setYawRotationMode();
  cam.pan(0, -1 * camHeight);

  cp5 = new ControlP5(this);
  cp5.setColorForeground(color(140,140,140));
  cp5.setColorBackground(color(200,200,200));
  cp5.setColorActive(color(77,77,77));  
  cp5.setColorLabel(color(77,77,77)); 
  cp5.setColorValue(color(77,77,77)); 

  cp5.addButton("OpenFile")
     .setPosition(10,10)
     .setSize(50,20)
     ;
  
  cp5.addTextlabel("currentFile")
                   .setText("")
                   .setPosition(60,15)
                   .setColorValue(color(77,77,77))
                    ;
    
  cp5.addCheckBox("wireframe")
    .setPosition(10,40)
    .setSize(10,10)
    .addItem("Wireframe", 10);

  cp5.addSlider("opacity")
     .setPosition(10,60)
     .setSize(100,10)
     .setRange(0,255)
     .setValue(100)
     .setVisible(false)
     ;
    
  cp5.addSlider("height")
     .setPosition(10,80)
     .setSize(10,600)
     .setRange(0,200)
     .setValue(128)
     .setVisible(false)
     ;
  cp5.getController("height").getValueLabel().align(ControlP5.LEFT, ControlP5.BOTTOM_OUTSIDE).setPaddingX(0);
  cp5.getController("height").getCaptionLabel().align(ControlP5.RIGHT, ControlP5.BOTTOM_OUTSIDE).setPaddingX(0);
  cp5.getController("height").setLabelVisible(false);
  cp5.setAutoDraw(false);

  sleigh = new Sleigh(1000);
  fileLoaded = false;
}


void draw() {
  background(#EEEEEE);
  pushMatrix();
  translate(40 + (-1 * sleigh.dim/2), 0, -1 * sleigh.dim/2);

  sleigh.draw();
  if (fileLoaded) {
    for (int i = 0; i < presents.length; i++) {   
      presents[i].draw();      
    }    
  }
  popMatrix();
    
  float [] pos = cam.getPosition();
  cam.pan(0, -1 * (camHeight + pos[1])); 
      
  cam.beginHUD();
  cp5.draw();
  cam.endHUD();
}



