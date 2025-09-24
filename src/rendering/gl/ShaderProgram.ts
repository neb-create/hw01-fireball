import {vec4, mat4} from 'gl-matrix';
import Drawable from './Drawable';
import {gl} from '../../globals';

var activeProgram: WebGLProgram = null;

export class Shader {
  shader: WebGLShader;

  constructor(type: number, source: string) {
    this.shader = gl.createShader(type);
    gl.shaderSource(this.shader, source);
    gl.compileShader(this.shader);

    if (!gl.getShaderParameter(this.shader, gl.COMPILE_STATUS)) {
      throw gl.getShaderInfoLog(this.shader);
    }
  }
};

class ShaderProgram {
  prog: WebGLProgram;

  attrPos: number;
  attrNor: number;
  attrCol: number;

  unifRes: WebGLUniformLocation;
  unifEye: WebGLUniformLocation;
  unifModel: WebGLUniformLocation;
  unifModelInvTr: WebGLUniformLocation;
  unifViewProj: WebGLUniformLocation;
  unifColorPrimary: WebGLUniformLocation;
  unifColorSecondary: WebGLUniformLocation;
  unifTime: WebGLUniformLocation;
  unifSet1: WebGLUniformLocation;
  unifSet2: WebGLUniformLocation
  unifSet3: WebGLUniformLocation

  constructor(shaders: Array<Shader>) {
    this.prog = gl.createProgram();

    for (let shader of shaders) {
      gl.attachShader(this.prog, shader.shader);
    }
    gl.linkProgram(this.prog);
    if (!gl.getProgramParameter(this.prog, gl.LINK_STATUS)) {
      throw gl.getProgramInfoLog(this.prog);
    }

    this.attrPos = gl.getAttribLocation(this.prog, "vs_Pos");
    this.attrNor = gl.getAttribLocation(this.prog, "vs_Nor");
    this.attrCol = gl.getAttribLocation(this.prog, "vs_Col");
    this.unifEye = gl.getUniformLocation(this.prog, "u_Eye");
    this.unifRes = gl.getUniformLocation(this.prog, "u_Res");
    this.unifModel      = gl.getUniformLocation(this.prog, "u_Model");
    this.unifModelInvTr = gl.getUniformLocation(this.prog, "u_ModelInvTr");
    this.unifViewProj   = gl.getUniformLocation(this.prog, "u_ViewProj");
    this.unifColorPrimary      = gl.getUniformLocation(this.prog, "u_Color_Primary");
    this.unifColorSecondary      = gl.getUniformLocation(this.prog, "u_Color_Secondary");
    this.unifTime       = gl.getUniformLocation(this.prog, "u_Time");
    this.unifSet1       = gl.getUniformLocation(this.prog, "u_Setting_1");
    this.unifSet2       = gl.getUniformLocation(this.prog, "u_Setting_2");
    this.unifSet3       = gl.getUniformLocation(this.prog, "u_Setting_3");
  }

  use() {
    if (activeProgram !== this.prog) {
      gl.useProgram(this.prog);
      activeProgram = this.prog;
    }
  }

  setRes(width: number, height: number) {
    this.use();
    if (this.unifRes !== -1) {
      gl.uniform1f(this.unifRes, width/height);
    }
  }

  setEye(eye: vec4) {
    this.use();
    if (this.unifEye !== -1) {
      gl.uniform4fv(this.unifEye, eye);
    }
  }

  setModelMatrix(model: mat4) {
    this.use();
    if (this.unifModel !== -1) {
      gl.uniformMatrix4fv(this.unifModel, false, model);
    }

    if (this.unifModelInvTr !== -1) {
      let modelinvtr: mat4 = mat4.create();
      mat4.transpose(modelinvtr, model);
      mat4.invert(modelinvtr, modelinvtr);
      gl.uniformMatrix4fv(this.unifModelInvTr, false, modelinvtr);
    }
  }

  setViewProjMatrix(vp: mat4) {
    this.use();
    if (this.unifViewProj !== -1) {
      gl.uniformMatrix4fv(this.unifViewProj, false, vp);
    }
  }

  setGeometryColorPrimary(color: vec4) {
    this.use();
    if (this.unifColorPrimary !== -1) {
      gl.uniform4fv(this.unifColorPrimary, color);
    }
  }
  setGeometryColorSecondary(color: vec4) {
    this.use();
    if (this.unifColorSecondary !== -1) {
      gl.uniform4fv(this.unifColorSecondary, color);
    }
  }

  setUniformSettings(settings: vec4) {
    this.use();
    if (this.unifSet1 !== -1) {
      gl.uniform1f(this.unifSet1, settings[0]);
    }
    if (this.unifSet2 !== -1) {
      gl.uniform1f(this.unifSet2, settings[1]);
    }
    if (this.unifSet3 !== -1) {
      gl.uniform1f(this.unifSet3, settings[2]);
    }
  }

  setUniformTime(time: number) {
    this.use;
    if (this.unifTime !== -1) {
      gl.uniform1f(this.unifTime, time);
    }
  }

  draw(d: Drawable) {
    this.use();

    if (this.attrPos != -1 && d.bindPos()) {
      gl.enableVertexAttribArray(this.attrPos);
      gl.vertexAttribPointer(this.attrPos, 4, gl.FLOAT, false, 0, 0);
    }

    if (this.attrNor != -1 && d.bindNor()) {
      gl.enableVertexAttribArray(this.attrNor);
      gl.vertexAttribPointer(this.attrNor, 4, gl.FLOAT, false, 0, 0);
    }

    d.bindIdx();
    gl.drawElements(d.drawMode(), d.elemCount(), gl.UNSIGNED_INT, 0);

    if (this.attrPos != -1) gl.disableVertexAttribArray(this.attrPos);
    if (this.attrNor != -1) gl.disableVertexAttribArray(this.attrNor);
  }
};

export default ShaderProgram;
