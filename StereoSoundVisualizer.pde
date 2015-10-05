/**
 * StereoSoundVisualizer
 * for Processing 1.5.1(not for Processing 2.x)
 * @author Sad Juno
 * @version 201510
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

// movieFileName: Record movie if not null and not empty
//final String movieFileName = "movie";
final String movieFileName = null;

// recordAsMovie: Record as PNG files if false(experimental)
final boolean recordAsMovie = true;

// fps: Frame per second
final int fps = 15;

//
// Classes
//

final class SceneInfo
{
  public final float tempo;
  public final String filePath;
  public final color bgColor;
  public final String visualizer;

  SceneInfo(
    float t,
    String path,
    color bg,
    String v)
  {
    tempo = t;
    filePath = path;
    bgColor = bg;
    visualizer = v;
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

final class CirclePointCreator
{
  final float distFromOrigin;
  
  CirclePointCreator(float dist)
  {
    distFromOrigin = dist;
  }
  
  PVector create(float angle)
  {
    final float r = radians(angle);
    return new PVector(distFromOrigin * cos(r), distFromOrigin * sin(r));
  }
}

abstract class VisualProcessor<T>
{
  protected final SoundPoints<T> soundPoints = new SoundPoints<T>();
  protected final float screenScale;
  protected final float maxSampleRate;
  protected final int hzIndexSize;
  
  protected VisualProcessor(
    float scale,
    float maxRate,
    int indexSize)
  {
    screenScale = scale;
    maxSampleRate = maxRate;
    hzIndexSize = indexSize;
  }
  
  final boolean isEmpty()
  {
    return soundPoints.isEmpty();
  }
  
  final void prepareDrawing()
  {
    if (requireEraseBackground()) {
      background(bgColor);
    }
  }

  protected final float scale(
    float value)
  {
    return value * screenScale;
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
  
  protected float getIndexMap(
    float hueBasis,
    int index)
  {
    float val = map(index, 0, hzIndexSize, 0, 360);
    return hueBasis < val ? val - hueBasis : val + (360 - hueBasis);
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

  protected final void hexagon(
    float r,
    float deg)
  {
      rotate(radians(deg));
      beginShape();
      vertex(r, 0, 0);
      for (int a = 0; a <= 360; a += 360 / 6) {
        final float rad = radians(a);
        vertex(r * cos(rad), r * sin(rad), 0);
      }
      vertex(r, 0, 0);
      endShape();
      rotate(-radians(deg));
  }  
  
  protected final void hexagon(
    float r)
  {
    hexagon(r, 0);
  }  

  protected final boolean matchName(
    String name)
  {
    return name.equals(getName());
  }

  abstract String getName();
  abstract void addPoint(float angle, FFT rightFft, FFT leftFft);
  abstract void visualize(boolean asPrimary, float angle);

  protected boolean requireEraseBackground()
  {
    return true;
  }
}

abstract class ChannelPointVisualProcessor extends VisualProcessor<ChannelPointInfo>
{
  protected final CirclePointCreator pointCreator;
  
  ChannelPointVisualProcessor(
    float screenScale,
    float dist,
    float maxRate,
    int indexSize)
  {
    super(screenScale, maxRate, indexSize);

    pointCreator = new CirclePointCreator(dist);
  }
  
  protected final PVector createCirclePoint(
    float angle)
  {
    return pointCreator.create(angle);
  }
  
  protected final ChannelPointInfo createPoint(
    float angle,
    float z,
    FFT fft)
  {
    final PVector pt = createCirclePoint(angle);
    return new ChannelPointInfo(pt.x, pt.y, z, fft.calcAvg(0, maxSampleRate), getMaxBandIndex(fft));
  }
}

final class ChannelLevelBezierVisualProcessor extends ChannelPointVisualProcessor
{
  private final float xStep;
  
  ChannelLevelBezierVisualProcessor(
    float screenScale,
    float dist,
    float maxRate,
    int indexSize,
    float tempo)
  {
    super(screenScale, dist, maxRate, indexSize);
    
    xStep = (tempo / 120.0) * scale(24.0 * 15 / fps);
  }
  
  private ChannelPointInfo createPoint(
    boolean asLeft,
    FFT fft)
  {
    final PVector pt = new PVector(0, fft.calcAvg(0, maxSampleRate) * pointCreator.distFromOrigin);
    return new ChannelPointInfo(pt.x * (asLeft ? -1 : 1), pt.y, 0, fft.calcAvg(0, maxSampleRate), getMaxBandIndex(fft));
  }

  String getName()
  {
    return "levelBezier";
  }
  
  void addPoint(
    float angle,
    FFT rightFft,
    FFT leftFft)
  {
    soundPoints.rightChannelPoints.add(createPoint(false, rightFft));
    soundPoints.leftChannelPoints.add(createPoint(true, leftFft));
  }

  void visualize(
    boolean asPrimary,
    float angle)
  {
    noFill();
    smooth();

    strokeWeight(scale(2));
    bezierDetail((int)scale(40));

    float intensity = 1.0 / 3;
    for (int index = 0; index < soundPoints.rightChannelPoints.size(); ++index) {
      float distRatio = index * 100.0 / soundPoints.rightChannelPoints.size();
      
      ChannelPointInfo rightPoint = soundPoints.rightChannelPoints.get(index);
      ChannelPointInfo leftPoint = soundPoints.leftChannelPoints.get(index);

      float h = 200 - (20.0 * rightPoint.maxLevelHzIndex / hzIndexSize);
      if (h < 0) {
        h += 360;
      }
      stroke(h, 100 - (50 * rightPoint.averageAmplitude), 80, distRatio);
      bezier(rightPoint.x, rightPoint.y, 0,
             leftPoint.x * intensity, leftPoint.y, leftPoint.z,
             rightPoint.x * intensity, -rightPoint.y, rightPoint.z,
             leftPoint.x, -leftPoint.y, 0);
      line(rightPoint.x, rightPoint.y, 0, leftPoint.x, -leftPoint.y, 0);
             
      h = 200 - (20.0 * leftPoint.maxLevelHzIndex / hzIndexSize);
      if (h < 0) {
        h += 360;
      }
      stroke(h, 100 - (50 * leftPoint.averageAmplitude), 80, distRatio);
      bezier(leftPoint.x, leftPoint.y, 0,
            rightPoint.x * intensity, rightPoint.y, rightPoint.z,
            leftPoint.x * intensity, -leftPoint.y, leftPoint.z,
            rightPoint.x, -rightPoint.y, 0);
      line(leftPoint.x, leftPoint.y, 0, rightPoint.x, -rightPoint.y, 0);
      rightPoint.x += scale(xStep);
      rightPoint.y += scale(rightPoint.averageAmplitude * 2.5);
      leftPoint.x -= scale(xStep);
      leftPoint.y += scale(leftPoint.averageAmplitude * 2.5);
    }
    if (asPrimary == false || 100.0 * 15 / fps < soundPoints.rightChannelPoints.size()) {
      soundPoints.rightChannelPoints.remove(0);
      soundPoints.leftChannelPoints.remove(0);
    }
  }
}

final class ChannelCurveVisualProcessor extends ChannelPointVisualProcessor
{
  private final float hueBasis = 300;
  private final int zAmount = 200;
  private final int depthCount = 50;

  ChannelCurveVisualProcessor(
    float screenScale,
    float dist,
    float maxRate,
    int indexSize)
  {
    super(screenScale, dist, maxRate, indexSize);
  }
  
  private ChannelPointInfo createPoint(
    float angle,
    FFT fft)
  {
    return createPoint(angle, (-zAmount * screenScale) * depthCount, fft);
  }
  
  private float getIndexMap(
    int index)
  {
    return 360 - getIndexMap(hueBasis, index);
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

  String getName()
  {
    return "curve";
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
    boolean asPrimary,
    float angle)
  {
    noFill();
    processChannel(soundPoints.rightChannelPoints, angle, false);
    processChannel(soundPoints.leftChannelPoints, (angle + 180) % 360, true);
  }
}

final class ChannelLineTunnelVisualProcessor extends ChannelPointVisualProcessor
{
  private final float hueBasis = 300;
  private final int zAmount = 50;
  private final int depthCount = 50;
  
  ChannelLineTunnelVisualProcessor(
    float screenScale,
    float dist,
    float maxRate,
    int indexSize)
  {
    super(screenScale, dist, maxRate, indexSize);
  }
  
  private ChannelPointInfo createPoint(
    float angle,
    FFT fft)
  {
    return createPoint(angle, (-zAmount * screenScale) * depthCount, fft);
  }
  
  private float getIndexMap(
    int index)
  {
    return getIndexMap(hueBasis, index);
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
        
        stroke(getIndexMap(info.maxLevelHzIndex), 40, 100, 10);
        float amp = info.averageAmplitude * (100 * screenScale) * (asLeft ? 1 : -1);
        curveVertex(info.x + amp, info.y + amp, info.z);
        ++index;
      }
    }
    endShape();
    
    curveTightness(0);
  }

  String getName()
  {
    return "lineTunnel";
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
    boolean asPrimary,
    float angle)
  {
    noFill();
    rotate(radians(angle));
    processChannel(soundPoints.rightChannelPoints, angle, false);
    processChannel(soundPoints.leftChannelPoints, (angle + 180) % 360, true);
    rotate(-radians(angle));
  }
  protected boolean requireEraseBackground()
  {
    return false;
  }
}

final class ChannelHexagonVisualProcessor extends ChannelPointVisualProcessor
{
  private final float hueBasis = 200;
  private final int zAmount = 200;
  private final int depthCount = 50;
  
  ChannelHexagonVisualProcessor(
    float screenScale,
    float dist,
    float maxRate,
    int indexSize)
  {
    super(screenScale, dist, maxRate, indexSize);
  }
  
  private ChannelPointInfo createPoint(
    float angle,
    FFT fft)
  {
    return createPoint(angle, (-zAmount * screenScale) * depthCount, fft);
  }
  
  private float getIndexMap(
    int index)
  {
    return 360 - getIndexMap(hueBasis, index);
  }
  
  private void processChannel(
    List<ChannelPointInfo> channelPoints,
    float angle,
    boolean asLeft)
  {
    float weight = 4 * screenScale;
    strokeWeight(weight);
    
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
        float x = info.x + amp;
        translate(x, info.y, info.z);
        hexagon(abs(amp));
        translate(-x, -info.y, -info.z);

        ++index;
      }
    }

    curveTightness(0);
    beginShape();
    for (ChannelPointInfo info : channelPoints) {
      stroke(getIndexMap(info.maxLevelHzIndex), 40, 100, 60);
      float amp = info.averageAmplitude * (200 * screenScale) * (asLeft ? 1 : -1);
      curveVertex(info.x + amp, info.y + amp, info.z);
    }
    if (1 < channelPoints.size()) {
      ChannelPointInfo lastInfo = channelPoints.get(channelPoints.size() - 1);
      curveVertex(lastInfo.x, lastInfo.y, 0);
    }
    endShape();
  }
  
  String getName()
  {
    return "hexagon";
  }
  
  void addPoint(
    float angle,
    FFT rightFft,
    FFT leftFft)
  {
    if (beatDetector.isKick()) {
      soundPoints.rightChannelPoints.add(createPoint(0, rightFft));
    }
    if (beatDetector.isHat()) {
      soundPoints.leftChannelPoints.add(createPoint(180, leftFft));
    }
  }

  void visualize(
    boolean asPrimary,
    float angle)
  {
    noFill();
    processChannel(soundPoints.rightChannelPoints, angle, false);
    processChannel(soundPoints.leftChannelPoints, (angle + 180) % 360, true);
  }
}

final class ChannelSpinningHexagonVisualProcessor extends ChannelPointVisualProcessor
{
  private final float hueBasis = 90;
  private final int zAmount = 400;
  private final int depthCount = 50;

  private float rotation = 0;
  
  ChannelSpinningHexagonVisualProcessor(
    float screenScale,
    float dist,
    float maxRate,
    int indexSize)
  {
    super(screenScale, dist, maxRate, indexSize);
  }
  
  private ChannelPointInfo createPoint(
    float angle,
    FFT fft)
  {
    return createPoint(angle, 0, fft);
  }
  
  private float getIndexMap(
    int index)
  {
    return 360 - getIndexMap(hueBasis, index);
  }
  
  private void processChannel(
    List<ChannelPointInfo> channelPoints,
    float angle,
    boolean asLeft)
  {
    float weight = 4 * screenScale;
    strokeWeight(weight);
    
    int index = 0;
    while (index < channelPoints.size()) {
      ChannelPointInfo info = channelPoints.get(index);
      if (info.z < (-zAmount * screenScale) * depthCount) {
        channelPoints.remove(index);
      }
      else {
        info.z -= zAmount * screenScale;

        stroke(getIndexMap(info.maxLevelHzIndex), 40, 100, 60);
        float amp = info.averageAmplitude * (200 * screenScale) * (asLeft ? 1 : -1);
        float x = info.x + amp;
        translate(x, info.y, info.z);
        hexagon(abs(amp), angle * amp);
        translate(-x, -info.y, -info.z);

        ++index;
      }
    }
  }

  String getName()
  {
    return "spinningHexagon";
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
    boolean asPrimary,
    float angle)
  {
    noFill();
    rotate(radians(rotation));
    processChannel(soundPoints.rightChannelPoints, angle, false);
    processChannel(soundPoints.leftChannelPoints, (angle + 180) % 360, true);
    
    rotation += 360 * (((60.0 / getTempo()) / 2) / frameRate);
    if (360 <= rotation) {
      rotation = 0;
    }
  }
}

final class ChannelSphereVisualProcessor extends ChannelPointVisualProcessor
{
  ChannelSphereVisualProcessor(
    float screenScale,
    float dist,
    float maxRate,
    int indexSize)
  {
    super(screenScale, dist, maxRate, indexSize);
  }
  
  private ChannelPointInfo createPoint(
    float angle,
    FFT fft)
  {
    return createPoint(angle, (-200 * screenScale) * 9, fft);
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
  
  String getName()
  {
    return "sphere";
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
    boolean asPrimary,
    float angle)
  {
    processChannel(soundPoints.rightChannelPoints, false);
    processChannel(soundPoints.leftChannelPoints, true);
  }
}

final class ChannelRingSwayingVisualProcessor extends VisualProcessor<ChannelRingSwayingVisualProcessor.Boids>
{
  /*
   * Reference Web page URL:
   * http://coderecipe.jp/recipe/gRrj53OPQF/
   * http://neareal.net/index.php?ComputerGraphics%2FUnity%2FTips%2FBoids%20Model
   */
  
  private final class Boids extends ChannelPointInfo
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

  private class BoidsComparator implements Comparator<Boids> {
    public int compare(Boids lhs, Boids rhs) {
      return (int)(rhs.z - lhs.z);
    }
  }

  private final BoidsComparator comparator = new BoidsComparator();
  private final int AGE_LIMIT = 20;  
  private final float hueBasis = 300;

  private final CirclePointCreator pointCreator;

  ChannelRingSwayingVisualProcessor(
    float screenScale,
    float dist,
    float maxRate,
    int indexSize,
    float tempo)
  {
    super(screenScale, maxRate, indexSize);
    
    pointCreator = new CirclePointCreator(dist);      
    randomSeed((int)tempo);
  }
  
  private Boids createPoint(
    float angle,
    FFT fft)
  {
    final PVector pt = pointCreator.create(angle);
    return new Boids(pt.x, pt.y, -pointCreator.distFromOrigin / 4, fft.calcAvg(0, maxSampleRate), getMaxBandIndex(fft));
  }
  
  private float getIndexMap(
    int index)
  {
    return 360 - getIndexMap(hueBasis, index);
  }
  
  private void processChannel(
    List<Boids> channelPoints,
    boolean asLeft,
    boolean asPrimary)
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
    if (asPrimary == false && channelPoints.isEmpty() == false) {
      channelPoints.remove(0);
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
  
  String getName()
  {
    return "ringSwaying";
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
    Collections.sort(soundPoints.rightChannelPoints, comparator);
    Collections.sort(soundPoints.leftChannelPoints, comparator);
  }
  
  void visualize(
    boolean asPrimary,
    float angle)
  {
    processChannel(soundPoints.rightChannelPoints, false, asPrimary);
    processChannel(soundPoints.leftChannelPoints, true, asPrimary);
  }

  protected void doPrepareDrawing()
  {
  }
}

interface Recorder
{
  abstract void recordFrame();
  abstract void finish();
}

final class MovieMakerRecorder implements Recorder
{
  private MovieMaker movieMaker;

  public MovieMakerRecorder(
    PApplet applet)
  {
    movieMaker = new MovieMaker(applet, width, height, movieFileName + ".mov", fps, MovieMaker.MOTION_JPEG_A, MovieMaker.BEST);
  }

  void recordFrame()
  {
    movieMaker.addFrame();
  }
  
  void finish()
  {
    movieMaker.finish();
    movieMaker = null;
  }
}

final class FrameRecorder implements Recorder
{
  public FrameRecorder(
    PApplet applet)
  {
  }

  void recordFrame()
  {
    saveFrame(movieFileName + "######.png");
  }
  
  void finish()
  {
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
Recorder recorder;
BeatDetect beatDetector;
List<SceneInfo> scenes;
List<String> visualizers;
boolean repeatPlayback;
color bgColor = color(0);

//
// Methods
//

void initMusics()
{
  XMLElement playlistDef = new XMLElement(this, "playlist.xml");
  scenes = new ArrayList<SceneInfo>();
  for (XMLElement child : playlistDef.getChildren()) {
    if (child.getName().equals("scenes")) {
      for (XMLElement scene : child.getChildren()) {
        String colorHex = scene.getStringAttribute("backgroundColor");
        scenes.add(new SceneInfo(scene.getFloatAttribute("tempo"),
                                 scene.getStringAttribute("file"),
                                 color(Integer.decode(colorHex)),
                                 scene.getStringAttribute("visualizer")));
      }
    }
    else if (child.getName().equals("visualizers")) {
      visualizers = new ArrayList<String>();
      for (XMLElement visualizer : child.getChildren()) {
        visualizers.add(visualizer.getContent());
      }
    }
  }
  repeatPlayback = (playlistDef.getStringAttribute("repeat").toLowerCase() == "yes");
}

float getTempo()
{
  return scenes.get(infoIndex).tempo;
}

void playNewSound()
{
  SceneInfo scene = scenes.get(infoIndex);
  bgColor = scene.bgColor;
  background(bgColor);
  
  player = minim.loadFile(scene.filePath, 1024);
  rightFft = new FFT(player.bufferSize(), player.sampleRate());
  leftFft = new FFT(player.bufferSize(), player.sampleRate());

  processors.clear();
  processors.add(new ChannelSphereVisualProcessor(screenScale, height / 2, player.sampleRate() / 2, rightFft.specSize() / 10));
  processors.add(new ChannelCurveVisualProcessor(screenScale, height / 2, player.sampleRate() / 2, rightFft.specSize() / 10));
  processors.add(new ChannelLineTunnelVisualProcessor(screenScale, height / 2, player.sampleRate() / 2, rightFft.specSize() / 10));
  processors.add(new ChannelHexagonVisualProcessor(screenScale, height / 2, player.sampleRate() / 2, rightFft.specSize() / 10));
  processors.add(new ChannelSpinningHexagonVisualProcessor(screenScale, height / 2, player.sampleRate() / 2, rightFft.specSize() / 10));
  processors.add(new ChannelRingSwayingVisualProcessor(screenScale, height / 6, player.sampleRate() / 2, rightFft.specSize() / 10, getTempo()));
  processors.add(new ChannelLevelBezierVisualProcessor(screenScale, height / 4, player.sampleRate() / 2, rightFft.specSize() / 100, getTempo()));

  if (visualizers.isEmpty() == false) {
    Iterator it =  processors.iterator();
    while (it.hasNext()) {
      if (visualizers.contains(((VisualProcessor)it.next()).getName()) == false) {
        it.remove();
      }
    }
  }

  if (scene.visualizer != null && scene.visualizer.isEmpty() == false) {
    for (int index = 0; index < processors.size() - 1; ++index) {
      if (processors.get(index).matchName(scene.visualizer)) {
        processors.add(processors.remove(index));
        break;
      }
    }
  }
  
  player.play();
}

void setup()
{
  size((int)(1280 * screenScale), (int)(720 * screenScale), OPENGL);
  smooth();
  colorMode(HSB, 360, 100, 100, 100);
  lights();
  noStroke();
  frameRate(fps);

  initMusics();
  beatDetector = new BeatDetect();
  beatDetector.detectMode(BeatDetect.FREQ_ENERGY);
  if (movieFileName != null && 0 < movieFileName.length()) {
    recorder = recordAsMovie ? new MovieMakerRecorder(this) : new FrameRecorder(this);
  }
  
  minim = new Minim(this);
  playNewSound();
}

void stop()
{
  super.stop();

  if (recorder != null) {
    recorder.finish();
    recorder = null;
  }
  player.close();
  minim.stop();
}

void draw()
{
  if (player.isPlaying() == false) {
    ++infoIndex;
    if (scenes.size() <= infoIndex) {
      if (repeatPlayback) {
        infoIndex = 0;
      }
      else {
        if (recorder != null) {
          recorder.finish();
          recorder = null;
        }
        exit();
        return;
      }
    }
    playNewSound();
  }

  beatDetector.detect(player.mix);
  rightFft.forward(player.right);
  leftFft.forward(player.left);

  translate(width / 2, height / 2);

//  PGraphicsOpenGL pgl = (PGraphicsOpenGL)g;
//  GL gl = pgl.beginGL();
//  gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE);
 
  VisualProcessor primaryProcessor = processors.get(processors.size() - 1);
  primaryProcessor.addPoint(angle, rightFft, leftFft);
  primaryProcessor.prepareDrawing();
  for (VisualProcessor processor : processors) {
    if (processor.isEmpty() == false) {
      processor.visualize(processor == primaryProcessor, angle);
    }
  }

//pgl.endGL();
  if (recorder != null) {
    recorder.recordFrame();
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
    bgColor = ~bgColor;
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
