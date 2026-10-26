(module
  (memory (export "memory") 1)

  (global $sample_rate (mut f32) (f32.const 48000))
  (global $pluse_duration (mut f32) (f32.const 2))  ;; in seconds

  (func $set_sample_rate (param $rate f32)
    local.get $rate
    global.set $sample_rate
  )

  (func $set_pluse_duration (param $dur f32)
    local.get $dur
    global.set $pluse_duration
  )

  ;; WebAssembly does not have a built-in sine function, so we will implement it
  ;; ourselves using Horner's method for the Taylor series expansion with hardcoded
  ;; coefficients.
  ;;     sin x ≈ x * (1 - 1/6 * x^2 * (1 - 1/20 * x^2 * (1 - 1/42 * x^2)))
  (func $sin (param $x f32) (result f32)
    (local $x2 f32)

    ;; Compute x^2
    local.get $x
    local.get $x
    f32.mul
    local.tee $x2

    ;; Compute the innermost term: (1 - 1/42 * x^2)
    f32.const -0.023809523809523808  ;; -1/42
    f32.mul                          ;; -1/42 * x^2
    f32.const 1
    f32.add                          ;; 1 - 1/42 * x^2

    ;; Compute the middle term: (1 - 1/20 * x^2 * (inner))
    f32.const -0.05                    ;; -1/20
    local.get $x2
    f32.mul                            ;; -1/20 * x^2
    f32.mul                            ;; -1/20 * x^2 * (inner)
    f32.const 1
    f32.add                            ;; 1 - 1/20 * x^2 * (inner)

    ;; Compute the outermost term: x * (1 - 1/6 * x^2 * (middle))
    f32.const -0.16666666666666666    ;; -1/6
    local.get $x2
    f32.mul                            ;; -1/6 * x^2
    f32.mul                            ;; -1/6 * x^2 * (middle)
    f32.const 1
    f32.add                            ;; 1 - 1/6 * x^2 * (middle)

    ;; Multiply by x to get the final sine approximation
    local.get $x
    f32.mul                            ;; x * (1 - 1/6 * x^2 * (middle))
  )

  ;; NOT WORKING!!! The sine approximation is not accurate enough for "long"
  ;; durations or high frequencies.
  (func $sine_wave (param $freq f32) (param $i f32) (result f32)
    local.get $i
    global.get $sample_rate
    f32.div
    local.get $freq
    f32.const 6.283185307179586  ;; 2 * pi
    f32.mul
    f32.mul
    call $sin
  )

  (func $attack (param $dur f32) (param $i f32) (result f32)
    (local $len f32)

    global.get $sample_rate
    local.get $dur
    f32.const 0.001
    f32.mul            ;; dur * 0.001 (convert ms to seconds)
    f32.mul
    f32.floor          ;; [sample_rate * dur * 0.001] (attack duration in samples)
    local.set $len

    local.get $i
    local.get $len
    f32.div            ;; a: cond != 0

    f32.const 1        ;; b: cond == 0

    ;; cond
    local.get $i
    local.get $len
    f32.lt

    select
  )

  (func $release (param $dur f32) (param $i f32) (result f32)
    (local $total_dur f32)
    (local $len f32)

    global.get $sample_rate
    global.get $pluse_duration
    f32.mul
    local.set $total_dur

    global.get $sample_rate
    local.get $dur
    f32.const 0.001
    f32.mul            ;; dur * 0.001 (convert ms to seconds)
    f32.mul
    f32.floor          ;; [sample_rate * dur * 0.001] (attack duration in samples)
    local.set $len

    local.get $total_dur
    local.get $i
    f32.sub
    local.get $len
    f32.div             ;; a: cond != 0, (total_dur - i) / len

    f32.const 1        ;; b: cond == 0

    ;; cond
    local.get $i
    local.get $total_dur
    local.get $len
    f32.sub
    f32.gt

    select
  )

  (func $envelope (param $atck f32) (param $rel f32) (param $i f32) (result f32)
    local.get $atck
    local.get $i
    call $attack

    local.get $rel
    local.get $i
    call $release
    
    f32.mul
  )

  (export "set_sample_rate" (func $set_sample_rate))
  (export "set_pluse_duration" (func $set_pluse_duration))
  (export "sine_wave" (func $sine_wave))
  (export "envelope" (func $envelope))
)
