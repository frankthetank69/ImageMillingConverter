int w = 400;
int h = 400;      //width and heigth of the finished product in mm
String imageName = "a.png";  //the name incl. file extension must be entered here. The file must be in the source directory. The picture should be close to the desired final ratio
boolean horizontal = false;    //default is vertical - horizontal or diagonal are not implemented yet
double angle = 90;         //angle of the Milling bit in degrees
double d = 1;              //diameter of the widest point  - maximum should be your milling bit outer most diameter
int verticalRes = h*10;       //vertical resolution  - default is 1mm
int feedRate = 800;        //cutting feedrate in mm/min
int travelSpeed = 2000;    //travel speed in mm/min
int diveSpeed = 300;       //plunging speed in mmm/min
int safeheight = 15;       //lifting height in mm
double offset = 10;        //offset from the edges in mm; should be at least half your tool diameter
double verticalOffset = 0; //the thickness of the top layer; will at least plunge to this depth
boolean invert = false;     //default is false - bright top layer and darker bottom layer

void setup() {
  size(1000, 1000);
  noLoop();
}

void draw() {
  boolean ready = false;
  ready = menu();

  if (ready) {
    PImage img = loadImage(imageName);

    img.resize(width, 0);
    img.filter(GRAY);

    image(img, 0, 0);
    w -= 2*offset;    //correct the outer most edges for the side clearence offset
    h -= 2*offset;
    d -= 2*verticalOffset*Math.tan(radians((float)angle/2));


    int darkest = 0;
    for (int i = 0; i < width; i++) {
      for (int j = 0; j < height; j++) {
        int cur = get(i, j);
        if (cur < darkest) {    //find the darkest color in the picure - this will be referenced to full plunge depth
          darkest = cur;
        }
      }
    }

    int numPasses = (int)(w / d);

    double [][]arr = new double[numPasses+1][verticalRes+1];  //stores the depth data for each probe point normalized to the color of the darkest pixel

    for (int i = 0; i < numPasses; i ++) {
      for (int j = 0; j < verticalRes; j++) {
        double posx = i*width/numPasses;
        double posy = j*height/verticalRes;
        double depth;
        if(!invert){
          depth = getColor(posx, posy, width/numPasses)/darkest;
        }else{
          depth = 1 - getColor(posx, posy, width/numPasses)/darkest;
        }

        //depth = (double)get(posx, posy)/darkest;
        arr[i][j] = depth * d/(2*Math.tan(radians((float)(angle/2))));
      }
    }

    //-------------------------------write to gcode file------------------------------------
    PrintWriter gcode;
    gcode = createWriter("program.nc");
    gcode.println("G28 F" + feedRate);
    for (int i = 0; i < arr.length; i++) {
      gcode.println("G01 X" + (i * w/numPasses + offset) + " Y"+ offset + " F" + travelSpeed);    //move to starting point
      gcode.println("G01 Z0 F" + diveSpeed);
      for (int j = 0; j < arr[0].length; j++) {
        double posx = i * w/numPasses + offset;
        double posy = j * h/verticalRes + offset;
        gcode.println("G01 X" + posx  +" Y" + posy + " Z-" + (arr[i][j] + verticalOffset) + " F"+feedRate);
      }
      gcode.println("G01 Z" + safeheight + " F" + feedRate);    //move up to safe height
    }
    gcode.println("G28 F" + travelSpeed);
    gcode.flush();
    gcode.close();



    //--------------------------display the expected picture----------------------------------

    //keep in mind this doesnt account for the side offsets; these are only visible in the exported gcode
    
    //translate((float)offset*width/w,(float)offset*height/h);
    
    if(!invert){
      background(color(255, 255, 255));
      fill(color(0, 0, 0));
    }else{
      background(color(0, 0, 0));
      fill(color(255,255,255));
    }
    
    strokeWeight(0);
    for (int i = 0; i < arr.length; i++) {
      for (int j = 0; j < arr[0].length; j++) {
        ellipse(i * width/numPasses, j * height/verticalRes, (int)(arr[i][j]*width/w*2*Math.tan(radians((float)angle/2))), (int)(arr[i][j]*width/w*2*Math.tan(radians((float)angle/2))));
      }
    }
  }
  saveFrame("piccc-######.png");
}


//average the color around an area of given coordinates (@posx,@posy) with a @w sided square
double getColor(double posx, double posy, int w) {
  double val = 0;
  int cnt = 0;
  for (int i = (int)posx - w/2; i < posx+w/2; i++) {
    for (int j = (int)posy - w/2; j < posy+w/2; j++) {
      val+=get(i, j);
      cnt++;
    }
  }
  return val/cnt;
}

boolean menu() {
  background(color(150, 150, 150));
  textSize(60);
  textAlign(CENTER);
  stroke(color(255, 255, 255));
  text("Image to Gcode converter", width/2, 60);
  textSize(30);
  text("©Justin Müller", width/2, 90);
  return true;
}
