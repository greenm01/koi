struct VertexIn {
  @location(0) pos: vec2<f32>,
  @location(1) uv: vec2<f32>,
  @location(2) maskUv: vec2<f32>,
  @location(3) color: vec4<f32>,
  @location(4) outerColor: vec4<f32>,
  @location(5) paintParams: vec4<f32>,
  @location(6) mode: f32,
  @location(7) aaMult: f32,
};

struct VertexOut {
  @builtin(position) pos: vec4<f32>,
  @location(0) uv: vec2<f32>,
  @location(1) maskUv: vec2<f32>,
  @location(2) color: vec4<f32>,
  @location(3) outerColor: vec4<f32>,
  @location(4) paintParams: vec4<f32>,
  @location(5) mode: f32,
  @location(6) aaMult: f32,
};

@group(0) @binding(0) var image: texture_2d<f32>;
@group(0) @binding(1) var imageSampler: sampler;

@vertex
fn vs_main(input: VertexIn) -> VertexOut {
  var out: VertexOut;
  out.pos = vec4<f32>(input.pos, 0.0, 1.0);
  out.uv = input.uv;
  out.maskUv = input.maskUv;
  out.color = input.color;
  out.outerColor = input.outerColor;
  out.paintParams = input.paintParams;
  out.mode = input.mode;
  out.aaMult = input.aaMult;
  return out;
}

fn edge_alpha(uv: vec2<f32>, aaMult: f32) -> f32 {
  if aaMult <= 0.0 {
    return 1.0;
  }

  let x = min(1.0, (1.0 - abs(uv.x * 2.0 - 1.0)) * aaMult);
  let y = min(1.0, uv.y);
  return x * y;
}

fn premul(color: vec4<f32>) -> vec4<f32> {
  return vec4<f32>(color.rgb * color.a, color.a);
}

fn sdroundrect(pt: vec2<f32>, extent: vec2<f32>, radius: f32) -> f32 {
  let ext = extent - vec2<f32>(radius, radius);
  let d = abs(pt) - ext;
  return min(max(d.x, d.y), 0.0) + length(max(d, vec2<f32>(0.0, 0.0))) - radius;
}

@fragment
fn fs_main(input: VertexOut) -> @location(0) vec4<f32> {
  let edgeAlpha = edge_alpha(input.maskUv, input.aaMult);
  if input.mode < 0.5 {
    let alpha = input.color.a * edgeAlpha;
    return vec4<f32>(input.color.rgb * alpha, alpha);
  }

  let sample = textureSample(image, imageSampler, input.uv);
  if input.mode < 1.5 {
    let alpha = input.color.a * sample.a * edgeAlpha;
    return vec4<f32>(input.color.rgb * sample.rgb * alpha, alpha);
  }

  if input.mode < 2.5 {
    let alpha = input.color.a * sample.r * edgeAlpha;
    return vec4<f32>(input.color.rgb * alpha, alpha);
  }

  let extent = input.paintParams.xy;
  let radius = input.paintParams.z;
  let feather = max(input.paintParams.w, 0.0001);
  let d = clamp((sdroundrect(input.uv, extent, radius) + feather * 0.5) / feather, 0.0, 1.0);
  let color = mix(premul(input.color), premul(input.outerColor), d);
  return color * edgeAlpha;
}
