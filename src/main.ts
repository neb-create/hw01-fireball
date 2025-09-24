import {vec3, vec4} from 'gl-matrix';
const Stats = require('stats-js');
import * as DAT from 'dat.gui';
import Icosphere from './geometry/Icosphere';
import Square from './geometry/Square';
import Cube from './geometry/Cube';
import OpenGLRenderer from './rendering/gl/OpenGLRenderer';
import Camera from './Camera';
import {setGL} from './globals';
import ShaderProgram, {Shader} from './rendering/gl/ShaderProgram';
import CubeFlat from './geometry/CubeFlat';

// Define an object with application parameters and button callbacks
// This will be referred to by dat.GUI's functions that add GUI elements.
const controls = {
  tesselations: 5,
  'Load Scene': loadScene, // A function pointer, essentially
  'Shape #1': swapToIcosphere, // A function pointer, essentially
  'Shape #2': swapToFlatCube, // A function pointer, essentially
  'Shape #3': swapToNonFlatCube, // A function pointer, essentially
  'Shape #4': swapToSquare, // A function pointer, essentially
  'Reset Settings' : resetSettings, // A function pointer, essentially
  'Fire Height': 0.8,
  'Noise Octave': 3,
  'Effect Size': 0.25, 
};

const gui = new DAT.GUI();

let icosphere: Icosphere;
let square: Square;
let cube: Cube;
let skybox: Cube;
let cubeflat: CubeFlat
let prevTesselations: number = 5;
let uTime: number = 0.0;

let render_type: number = 0;

var palette = {
    'Color #1': [ 230, 205, 205 ],
    'Color #2': [ 132, 144, 202 ],
  };

function resetSettings() {
  controls.tesselations = 5;
  palette['Color #1'] = [ 230, 205, 205 ];
  palette['Color #2'] = [ 132, 144, 202 ];
  render_type = 0;
  controls['Fire Height'] = 0.6;
  controls['Noise Octave'] = 2;
  controls['Effect Size'] = 0.5;
  
  gui.__controllers.forEach(controller => controller.updateDisplay());
}

function loadScene() {
  icosphere = new Icosphere(vec3.fromValues(0, 0, 0), 1, controls.tesselations);
  icosphere.create();
  square = new Square(vec3.fromValues(0, 0, 0));
  square.create();
  cube = new Cube(vec3.fromValues(0, 0, 0));
  cube.create();
  skybox = new Cube(vec3.fromValues(0, 0, 0));
  skybox.create();
  cubeflat = new CubeFlat(vec3.fromValues(0, 0, 0));
  cubeflat.create();
}

function swapToIcosphere() {
  render_type = 0;
}
function swapToFlatCube() {
  render_type = 1;
}
function swapToNonFlatCube() {
  render_type = 2;
}
function swapToSquare() {
  render_type = 3;
}

function toVec4(color: number[]): vec4 {
  return vec4.fromValues(color[0]/255.0, color[1]/255.0, color[2]/255.0, 1);
}

function main() {
  // Initial display for framerate
  const stats = Stats();
  stats.setMode(0);
  stats.domElement.style.position = 'absolute';
  stats.domElement.style.left = '0px';
  stats.domElement.style.top = '0px';
  document.body.appendChild(stats.domElement);

  // Add controls to the gui
  gui.add(controls, 'tesselations', 0, 8).step(1);
  //gui.add(controls, 'Load Scene');
  //gui.add(controls, 'Shape #1');
  //gui.add(controls, 'Shape #2');
  //gui.add(controls, 'Shape #3');
  //gui.add(controls, 'Shape #4');
  gui.add(controls, 'Fire Height', 0.0, 1.6).step(0.1);
  gui.add(controls, 'Noise Octave', 1, 5).step(1);
  gui.add(controls, 'Effect Size', 0.0, 0.8).step(0.1);
  gui.addColor(palette, 'Color #1');
  gui.addColor(palette, 'Color #2');
  gui.add(controls, 'Reset Settings');

  // get canvas and webgl context
  const canvas = <HTMLCanvasElement> document.getElementById('canvas');
  const gl = <WebGL2RenderingContext> canvas.getContext('webgl2');
  if (!gl) {
    alert('WebGL 2 not supported!');
  }
  // `setGL` is a function imported above which sets the value of `gl` in the `globals.ts` module.
  // Later, we can import `gl` from `globals.ts` to access it
  setGL(gl);

  // Initial call to load scene
  loadScene();

  resetSettings();

  const camera = new Camera(vec3.fromValues(0, 0, 5), vec3.fromValues(0, 0, 0));

  const renderer = new OpenGLRenderer(canvas);
  renderer.setClearColor(0.2, 0.2, 0.2, 1);
  gl.enable(gl.DEPTH_TEST);

  const lambert = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, require('./shaders/lambert-vert.glsl')),
    new Shader(gl.FRAGMENT_SHADER, require('./shaders/lambert-frag.glsl')),
  ]);

  // This function will be called every frame
  function tick() {
    uTime++;
    camera.update();
    stats.begin();
    gl.viewport(0, 0, window.innerWidth, window.innerHeight);
    renderer.clear();
    if(controls.tesselations != prevTesselations)
    {
      prevTesselations = controls.tesselations;
      icosphere = new Icosphere(vec3.fromValues(0, 0, 0), 1, prevTesselations);
      icosphere.create();
    }

    let color1 = toVec4(palette['Color #1']);
    let color2 = toVec4(palette['Color #2']);

    let render_geom = [];
    if (render_type === 0) {
      render_geom.push(icosphere);
    } else if (render_type === 1) {
      render_geom.push(cubeflat);
    } else if (render_type === 2) {
      render_geom.push(cube);
    } else if (render_type === 3) {
      render_geom.push(square);
    }
    render_geom.push(skybox);

    let setting_input = vec4.fromValues(controls['Fire Height'], controls['Noise Octave'], controls['Effect Size'] - 0.05, 0);
    renderer.render(camera, lambert, render_geom, setting_input, color1, color2, uTime);

    stats.end();

    // Tell the browser to call `tick` again whenever it renders a new frame
    requestAnimationFrame(tick);
  }

  window.addEventListener('resize', function() {
    renderer.setSize(window.innerWidth, window.innerHeight);
    camera.setAspectRatio(window.innerWidth / window.innerHeight);
    camera.updateProjectionMatrix();
  }, false);

  renderer.setSize(window.innerWidth, window.innerHeight);
  camera.setAspectRatio(window.innerWidth / window.innerHeight);
  camera.updateProjectionMatrix();

  // Start the render loop
  tick();
}

main();
