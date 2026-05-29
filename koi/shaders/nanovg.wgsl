struct VertexIn {
  @location(0) pos: vec2<f32>,
  @location(1) uv: vec2<f32>,
  @location(2) maskUv: vec2<f32>,
  @location(3) color: vec4<f32>,
  @location(4) mode: f32,
  @location(5) aaMult: f32,
};

struct VertexOut {
  @builtin(position) pos: vec4<f32>,
  @location(0) uv: vec2<f32>,
  @location(1) maskUv: vec2<f32>,
  @location(2) color: vec4<f32>,
  @location(3) mode: f32,
  @location(4) aaMult: f32,
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

  let alpha = input.color.a * sample.r * edgeAlpha;
  return vec4<f32>(input.color.rgb * alpha, alpha);
}
