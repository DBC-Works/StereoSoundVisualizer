/**
 * StereoSoundVisualizer
 * for Processing 1.5.1(not for Processing 2.x)
 * @author Sad Juno
 * @version 201503
 * @link https://github.com/DBC-Works
 * @license http://opensource.org/licenses/MIT
 */

//
// Imports
//

import java.util.Iterator;
import java.util.List;
import java.util.ArrayList;
import javax.media.opengl.*;  
import ddf.minim.*;
import ddf.minim.signals.*;
import ddf.minim.analysis.*;
import ddf.minim.effects.*;
import processing.opengl.*;
import processing.video.*;

//
// Settings
//

// screenScale: 1.0 - HD(1280x720) / 1.5 - Full HD(1920x1080)
final float screenScale = 4 / 4.0;

// record: Record movie if true 
final boolean record = false;

// repeatPlayback: Repeat playback if true 
final boolean repeatPlayback = false;

// sounds: Play back sound info(tempo, file(wav, mp3, ...)
SoundInfo[] sounds = {
  new SoundInfo(122, "Initial Revelry.mp3"),
  new SoundInfo(104, "Calling.mp3"),
};

// bgBrightness: Background brightness(0 - black / 360 - white)
float bgBrightness = 0;

//
// Classes
//

final class SoundInfo
{
  public final float tempo;
  public final String filePath;

  SoundInfo(
    float t,
    String path)
  {
    tempo = t;
    filePath = path;
  }
}

class ChannelPointInfo
{
  float x;
  float y;
  float z;
  float averageAmplitude;
  int maxLevelHzIndex;
  
  ChannelPointInfo(
    float posX,
    float posY,
    float posZ,
    float avgAmp,
    int index)
  {
    x = posX;
    y = posY;
    z = posZ;
    averageAmplitude = avgAmp;
    maxLevelHzIndex = index;
  }
}

final class SoundPoints<T>
{
  final List<T> rightChannelPoints = new ArrayList<T>();
  final List<T> leftChannelPoints = new ArrayList<T>();
  
  boolean isEmpty()
  {
    return rightChannelPoints.size() == 0 && leftChannelPoints.size() == 0;
  }
}

abstract class VisualProcessor<T>
{
  protected final SoundPoints<T> soundPoints = new SoundPoints<T>();
  protected final float screenScale;
  protected final int hzIndexSize;
  
  protected VisualProcessor(
    float scale,
    int indexSize)
  {
    screenScale = scale;
    hzIndexSize = indexSize;
  }
  
  final boolean isEmpty()
  {
    return soundPoints.isEmpty();
  }
  
  protected final int getMaxBandIndex(
    FFT fft)
  {
    int maxIndex = 0;
    float maxBand = 0.0;
    for(int index = 0; index < hzIndexSize; ++index) {
      final float b = fft.getBand(index);
      if (maxBand < b) {
        maxIndex = index;
        maxBand = b;
      }
    }
    return maxIndex;
  }

  protected final void circle(
    float r)
  {
      beginShape();
      curveVertex(r, 0, 0);
      for (int a = 0; a <= 360; a += 30) {
        final float rad = radians(a);
        curveVertex(r * cos(rad), r * sin(rad), 0);
      }
      curveVertex(r, 0, 0);
      endShape();
  }  

  abstract void addPoint(float angle, FFT rightFft, FFT leftFft);
  abstract void visualize(float angle);
}

final class ChannelCurveVisualProcessor extends VisualProcessor<ChannelPointInfo>
{
  private final float distFromOrigin;
  private final float maxSampleRate;
  private final float hueBasis = 300;
  private final int zAmount = 200;
  private final int depthCount = 50;
  
  ChannelCurveVisualProcessor(
    float screenScale,
    float dist,
    float maxRate,
    int indexSize)
  {
    super(screenScale, indexSize);

    distFromOrigin = dist;
    maxSampleRate = maxRate;
  }
  
  private ChannelPointInfo createPoint(
    float angle,
    FFT fft)
  {
    final float r = radians(angle);
    return new ChannelPointInfo(distFromOrigin * cos(r), distFromOrigin * sin(r), (-zAmount * screenScale) * depthCount, fft.calcAvg(0, maxSampleRate), getMaxBandIndex(fft));
  }
  
  private float getIndexMap(
    int index)
  {
    float val = map(index, 0, hzIndexSize, 0, 360);
    if (hueBasis < val) {
      val -= hueBasis;
    }
    else {
      val += (360 - hueBasis);
    }
    return 360 - val;
  }
  
  private void processChannel(
    List<ChannelPointInfo> channelPoints,
    float angle,
    boolean asLeft)
  {
    curveTightness((angle - 180) / 180);
    
    float weight = 4 * screenScale;
    strokeWeight(weight);
    
    beginShape();
    int index = 0;
    while (index < channelPoints.size()) {
      ChannelPointInfo info = channelPoints.get(index);
      if (0 < info.z) {
        channelPoints.remove(index);
      }
      else {
        info.z += zAmount * screenScale;
        
        stroke(getIndexMap(info.maxLevelHzIndex), 40, 100, 60);
        float amp = info.averageAmplitude * (200 * screenScale) * (asLeft ? 1 : -1);
        curveVertex(info.x + amp, info.y + amp, info.z);
        ++index;
      }
    }
    endShape();

    curveTightness(0);
    strokeWeight(weight / 2);
    float r = 60 * screenScale;
    for (ChannelPointInfo info : channelPoints) {
      stroke(getIndexMap(info.maxLevelHzIndex), 33, 100, 60);
      float amp = info.averageAmplitude * (200 * screenScale) * (asLeft ? 1 : -1);
      pushMatrix();
      translate(info.x + amp, info.y + amp, info.z);
      circle(r);
      translate(0, 0, 10 * screenScale);
      circle(r * 1.2);
      popMatrix();
    }
  }
  
  void addPoint(
    float angle,
    FFT rightFft,
    FFT leftFft)
  {
    soundPoints.rightChannelPoints.add(createPoint(angle, rightFft));
    soundPoints.leftChannelPoints.add(createPoint((angle + 180) % 360, leftFft));
  }

  void visualize(
    float angle)
  {
    noFill();
    processChannel(soundPoints.rightChannelPoints, angle, false);
    processChannel(soundPoints.leftChannelPoints, (angle + 180) % 360, true);
  }
}

final class ChannelSphereVisualProcessor extends VisualProcessor<ChannelPointInfo>
{
  private final float distFromOrigin;
  private final float maxSampleRate;
  
  ChannelSphereVisualProcessor(
    float screenScale,
    float dist,
    float maxRate,
    int indexSize)
  {
    super(screenScale, indexSize);
    
    distFromOrigin = dist;
    maxSampleRate = maxRate;
  }
  
  private ChannelPointInfo createPoint(
    float angle,
    FFT fft)
  {
    final float r = radians(angle);
    return new ChannelPointInfo(distFromOrigin * cos(r), distFromOrigin * sin(r), (-200 * screenScale) * 9, fft.calcAvg(0, maxSampleRate), getMaxBandIndex(fft));
  }
  
  private float getIndexMap(
    int index)
  {
    return map(index, 0, hzIndexSize, 240, 54);
  }
  
  private void processChannel(
    List<ChannelPointInfo> channelPoints,
    boolean asLeft)
  {
    int index = 0; 
    while (index < channelPoints.size()) {
      ChannelPointInfo info = channelPoints.get(index);
      if (0 < info.z) {
        channelPoints.remove(index);
      }
      else {
        info.z += 200;

        pushMatrix();
        translate(info.x, info.y, info.z);
        fill(getIndexMap(info.maxLevelHzIndex), 64, 100, info.averageAmplitude * 50);
        sphere(height / 2 / 8);
        popMatrix();

        ++index;
      }
    }
  }
  
  void addPoint(
    float angle,
    FFT rightFft,
    FFT leftFft)
  {
    soundPoints.rightChannelPoints.add(createPoint(angle, rightFft));
    soundPoints.leftChannelPoints.add(createPoint((angle + 180) % 360, leftFft));
  }
  void visualize(
    float angle)
  {
    processChannel(soundPoints.rightChannelPoints, false);
    processChannel(soundPoints.leftChannelPoints, true);
  }
}

final class ChannelRingSwayingVisualProcessor extends VisualProcessor<ChannelRingSwayingVisualProcessor.Boids>
{
  // http://coderecipe.jp/recipe/gRrj53OPQF/
  
  final class Boids extends ChannelPointInfo
  {
    final PVector velocity;
    int age;
    
    Boids(
      float posX,
      float posY,
      float posZ,
      float avgAmp,
      int index)
    {
      super(posX, posY, posZ, avgAmp, index);
      
      velocity = new PVector(0, 0, 0);
      age = 0;
    }
    
    float getReferenceDistanceFrom(Boids b)
    {
      float distx = x - b.x;
      float disty = y - b.y;
      float distz = z - b.z;
      return distx * distx + disty * disty + distz * distz;
    }

    PVector calcCenterOfHerd(
      List<Boids> channelBoids)
    {
      PVector center = new PVector(0, 0, 0);

      for (Boids boids : channelBoids) {
        if (this != boids) {
          center.x += boids.x;
          center.y += boids.y;
          center.z += boids.z;
        }
      }
      center.x /= channelBoids.size() - 1;
      center.y /= channelBoids.size() - 1;
      center.z /= channelBoids.size() - 1;
      
      return center;
    }
    
    void addVelocity(
    PVector target)
    {
      // rule 1
      final float t = 0.95;
      velocity.x += (target.x - x) * (1 - t);
      velocity.y += (target.y - y) * (1 - t);
      velocity.z += (target.z - z) * (1 - t);
    }
    
    void tryKeepDistance(
      List<Boids> channelBoids)
    {
      // rule 2
      for (Boids boids : channelBoids) {
        if (this != boids) {
          if (getReferenceDistanceFrom(boids) < random(50000) * screenScale) {
            velocity.x -= boids.x - x;
            velocity.y -= boids.y - y;
            velocity.z -= boids.z - z;
          }
        }        
      }
    }
    
    void trySync(
      List<Boids> channelBoids)
    {
      // rule 3
      PVector vel = new PVector(0, 0, 0);
      for (Boids boids : channelBoids) {
        if (this != boids) {
          vel.x += boids.velocity.x;
          vel.y += boids.velocity.y;
          vel.z += boids.velocity.z;
        }        
      }
      vel.x /= channelBoids.size() - 1;
      vel.y /= channelBoids.size() - 1;
      vel.z /= channelBoids.size() - 1;
      
      final float d = 100 * screenScale;
      velocity.x += (vel.x - velocity.x) / d;
      velocity.y += (vel.y - velocity.y) / d;
      velocity.z += (vel.z - velocity.z) / d;
    }
    
    void adjustAndMove()
    {
      float mag = velocity.mag();
      final float magLimit = 20 * screenScale;
      if (magLimit <= mag) {
        float r = magLimit / mag;
        velocity.x *= r;
        velocity.y *= r;
        velocity.z *= r;
      }
      if ((x < -(width / 2) && velocity.x < 0) || (width / 2 <= x && 0 < velocity.x)) {
        velocity.x *= -1;
      }
      if ((y < -(height / 2) && velocity.y < 0) || (height / 2 <= y && 0 < velocity.y)) {
        velocity.y *= -1;
      }
      if ((z < -height && velocity.z < 0) || (0 <= z && 0 < velocity.z)) {
        velocity.z *= -1;
      }
      
      x += velocity.x;
      y += velocity.y;
      z += velocity.z;
      
      ++age;
    }
  }

  private final int AGE_LIMIT = 20;  
  private final float distFromOrigin;
  private final float maxSampleRate;
  private final float hueBasis = 300;

  ChannelRingSwayingVisualProcessor(
    float screenScale,
    float dist,
    float maxRate,
    int indexSize,
    float tempo)
  {
    super(screenScale, indexSize);
    
    distFromOrigin = dist;
    maxSampleRate = maxRate;
    
    randomSeed((int)tempo);
  }
  
  private Boids createPoint(
    float angle,
    FFT fft)
  {
    final float r = radians(angle);
    return new Boids(distFromOrigin * cos(r), distFromOrigin * sin(r), -distFromOrigin / 4, fft.calcAvg(0, maxSampleRate), getMaxBandIndex(fft));
  }
  
  private float getIndexMap(
    int index)
  {
    float val = map(index, 0, hzIndexSize, 0, 360);
    if (hueBasis < val) {
      val -= hueBasis;
    }
    else {
      val += (360 - hueBasis);
    }
    return 360 - val;
  }
  
  private void processChannel(
    List<Boids> channelPoints,
    boolean asLeft)
  {
    noFill();
    strokeWeight(2 * screenScale);
    for (Boids boids : channelPoints) {
      pushMatrix();
      translate(boids.x, boids.y, boids.z);
      stroke(getIndexMap(boids.maxLevelHzIndex), 64, 100, 100 * ((channelPoints.size() - boids.age) / (float)channelPoints.size()));
      circle((boids.averageAmplitude * 20) * screenScale);
      popMatrix();
    }
    Iterator it = channelPoints.iterator();
    while (it.hasNext()) {
      Boids boids = (Boids)it.next();
      if (AGE_LIMIT < boids.age) {
        it.remove();
      }
    }
    
    for (Boids boids : channelPoints) {
      // rule1
      PVector center = boids.calcCenterOfHerd(channelPoints);
      boids.addVelocity(center); 
      
      // rule2
      boids.tryKeepDistance(channelPoints);
      
      // rule3
      boids.trySync(channelPoints);
      
      // adjustAndMove
      boids.adjustAndMove();
    }
  }
  
  void addPoint(
    float angle,
    FFT rightFft,
    FFT leftFft)
  {
    if (isEmpty()) {
      for (int count = 0; count < AGE_LIMIT; ++count) {
        soundPoints.rightChannelPoints.add(new Boids(random(width) - width / 2, random(height) - height / 2, -random(height / 4), 0, 0));
        soundPoints.leftChannelPoints.add(new Boids(random(width) - width / 2, random(height) - height / 2, -random(height / 4), 0, 0));
      }
    }
    soundPoints.rightChannelPoints.add(createPoint(angle, rightFft));
    soundPoints.leftChannelPoints.add(createPoint((angle + 180) % 360, leftFft));
  }
  
  void visualize(
    float angle)
  {
    processChannel(soundPoints.rightChannelPoints, false);
    processChannel(soundPoints.leftChannelPoints, true);
  }
}

//
// Fields
//

List<VisualProcessor> processors = new ArrayList<VisualProcessor>();
float angle = 0.0;
int infoIndex = 0;
Minim minim;
AudioPlayer player;
FFT rightFft;
FFT leftFft;
MovieMaker movie;

//
// Methods
//

float getTempo()
{
  return sounds[infoIndex].tempo;
}

void playNewSound()
{
  background(bgBrightness);
  
  player = minim.loadFile(sounds[infoIndex].filePath, 1024);
  rightFft = new FFT(player.bufferSize(), player.sampleRate());
  leftFft = new FFT(player.bufferSize(), player.sampleRate());

  processors.clear();
  processors.add(new ChannelSphereVisualProcessor(screenScale, height / 2, player.sampleRate() / 2, rightFft.specSize() / 10));
  processors.add(new ChannelCurveVisualProcessor(screenScale, height / 2, player.sampleRate() / 2, rightFft.specSize() / 10));
  processors.add(new ChannelRingSwayingVisualProcessor(screenScale, height / 6, player.sampleRate() / 2, rightFft.specSize() / 10, getTempo()));
  
  player.play();
}

void setup()
{
  size((int)(1280 * screenScale), (int)(720 * screenScale), OPENGL);
  smooth();
  colorMode(HSB, 360, 100, 100, 100);
  lights();
  noStroke();
  frameRate(15);

  if (record) {
    movie = new MovieMaker(this, width, height, "movie.mov", 15, MovieMaker.MOTION_JPEG_A, MovieMaker.BEST);
  }
  
  minim = new Minim(this);
  playNewSound();
}

void stop()
{
  super.stop();

  if (movie != null) {
    movie.finish();
    movie = null;
  }
  player.close();
  minim.stop();
}

void draw()
{
  if (player.isPlaying() == false) {
    ++infoIndex;
    if (sounds.length <= infoIndex) {
      if (repeatPlayback) {
        infoIndex = 0;
      }
      else {
        if (movie != null) {
          movie.finish();
          movie = null;
        }
        exit();
        return;
      }
    }
    playNewSound();
  }

  rightFft.forward(player.right);
  leftFft.forward(player.left);

  background(bgBrightness);
  translate(width / 2, height / 2);
  
  processors.get(processors.size() - 1).addPoint(angle, rightFft, leftFft);
  for (VisualProcessor processor : processors) {
    processor.visualize(angle);
  }
  
  if (movie != null) {
    movie.addFrame();
  }
  
  angle += 360 * (((60.0 / getTempo()) * 4) / frameRate);
  if (360 <= angle) {
    angle = 0;
  }
}

//
// Event handlers
//

void mousePressed(){
  if (mouseButton == LEFT) {
    bgBrightness = bgBrightness == 0 ? 360 : 0;
  }
} 

void keyTyped() {
  if ('0' <= key && key <='9') {
    int index = (key - '0') % processors.size();
    processors.add(processors.remove(index));
  }
  else if (key == ' ') {
    processors.add(processors.remove(0));
  }
}
