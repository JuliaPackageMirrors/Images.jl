### Edge and Gradient Related Image Operations ###

# Magnitude of gradient, calculated from X and Y image gradients
"""
```
m = magnitude(grad_x, grad_y)
```

Calculates the magnitude of the gradient images given by `grad_x` and `grad_y`.
Equivalent to ``sqrt(grad_x.^2 + grad_y.^2)``.

Returns a magnitude image the same size as `grad_x` and `grad_y`.
"""
magnitude(grad_x::AbstractArray, grad_y::AbstractArray) =
    @compat hypot.(grad_x, grad_y)
magnitude(img1::AbstractImageDirect, img2::AbstractImageDirect) =
    hypot(img1, img2)

# Phase (angle of steepest gradient ascent), calculated from X and Y gradient images
"""
```
p = phase(grad_x, grad_y)
```

Calculates the rotation angle of the gradient images given by `grad_x` and
`grad_y`. Equivalent to ``atan2(-grad_y, grad_x)``.  When both ``grad_x[i]`` and
``grad_y[i]`` are zero, the corresponding angle is set to zero.

Returns a phase image the same size as `grad_x` and `grad_y`, with values in [-pi,pi].
"""
function phase{T}(grad_x::AbstractArray{T}, grad_y::AbstractArray{T})
    EPS = sqrt(eps(eltype(T)))
    # Set phase to zero when both gradients are close to zero
    reshape([atan2(-grad_y[i], grad_x[i]) * ((abs(grad_x[i]) > EPS) | (abs(grad_y[i]) > EPS))
             for i=1:length(grad_x)], size(grad_x))
end

function phase(grad_x::AbstractImageDirect, grad_y::AbstractImageDirect)
    img = copyproperties(grad_x, phase(data(grad_x), data(grad_y)))
    img["limits"] = (-float(pi),float(pi))
    img
end

# Orientation of the strongest edge at a point, calculated from X and Y gradient images
# Note that this is perpendicular to the phase at that point, except where
# both gradients are close to zero.

"""
```
orient = orientation(grad_x, grad_y)
```

Calculates the orientation angle of the strongest edge from gradient images
given by `grad_x` and `grad_y`.  Equivalent to ``atan2(grad_x, grad_y)``.  When
both `grad_x[i]` and `grad_y[i]` are zero, the corresponding angle is set to
zero.

Returns a phase image the same size as `grad_x` and `grad_y`, with values in
[-pi,pi].
"""
function orientation{T}(grad_x::AbstractArray{T}, grad_y::AbstractArray{T})
    EPS = sqrt(eps(eltype(T)))
    # Set orientation to zero when both gradients are close to zero
    # (grad_y[i] should probably be negated here, but isn't for consistency with earlier releases)
    reshape([atan2(grad_x[i], grad_y[i]) * ((abs(grad_x[i]) > EPS) | (abs(grad_y[i]) > EPS))
             for i=1:length(grad_x)], size(grad_x))
end

function orientation(grad_x::AbstractImageDirect, grad_y::AbstractImageDirect)
    img = copyproperties(grad_x, orientation(data(grad_x), data(grad_y)))
    img["limits"] = (-float(pi),float(pi))
    img
end

# Return both the magnitude and phase in one call
"""
`m, p = magnitude_phase(grad_x, grad_y)`

Convenience function for calculating the magnitude and phase of the gradient
images given in `grad_x` and `grad_y`.  Returns a tuple containing the magnitude
and phase images.  See `magnitude` and `phase` for details.
"""
magnitude_phase(grad_x::AbstractArray, grad_y::AbstractArray) = (magnitude(grad_x,grad_y), phase(grad_x,grad_y))

# Return the magnituded and phase of the gradients in an image
function magnitude_phase(img::AbstractArray, method::AbstractString="ando3", border::AbstractString="replicate")
    grad_x, grad_y = imgradients(img, method, border)
    return magnitude_phase(grad_x, grad_y)
end

# Return the x-y gradients and magnitude and phase of gradients in an image
"""
```
grad_x, grad_y, mag, orient = imedge(img, [method], [border])
```

Edge-detection filtering. `method` is one of `"sobel"`, `"prewitt"`, `"ando3"`,
`"ando4"`, `"ando4_sep"`, `"ando5"`, or `"ando5_sep"`, defaulting to `"ando3"`
(see the functions of the same name for more information).  `border` is any of
the boundary conditions specified in `padarray`.

Returns a tuple `(grad_x, grad_y, mag, orient)`, which are the horizontal
gradient, vertical gradient, and the magnitude and orientation of the strongest
edge, respectively.
"""
function imedge(img::AbstractArray, method::AbstractString="ando3", border::AbstractString="replicate")
    grad_x, grad_y = imgradients(img, method, border)
    mag = magnitude(grad_x, grad_y)
    orient = orientation(grad_x, grad_y)
    return (grad_x, grad_y, mag, orient)
end

# Thin edges
"""
```
thinned = thin_edges(img, gradientangle, [border])
thinned, subpix = thin_edges_subpix(img, gradientangle, [border])
thinned, subpix = thin_edges_nonmaxsup(img, gradientangle, [border]; [radius::Float64=1.35], [theta=pi/180])
thinned, subpix = thin_edges_nonmaxsup_subpix(img, gradientangle, [border]; [radius::Float64=1.35], [theta=pi/180])
```

Edge thinning for 2D edge images.  Currently the only algorithm available is
non-maximal suppression, which takes an edge image and its gradient angle, and
checks each edge point for local maximality in the direction of the gradient.
The returned image is non-zero only at maximal edge locations.

`border` is any of the boundary conditions specified in `padarray`.

In addition to the maximal edge image, the `_subpix` versions of these functions
also return an estimate of the subpixel location of each local maxima, as a 2D
array or image of `Graphics.Point` objects.  Additionally, each local maxima is
adjusted to the estimated value at the subpixel location.

Currently, the `_nonmaxsup` functions are identical to the first two function
calls, except that they also accept additional keyword arguments.  `radius`
indicates the step size to use when searching in the direction of the gradient;
values between 1.2 and 1.5 are suggested (default 1.35).  `theta` indicates the
step size to use when discretizing angles in the `gradientangle` image, in
radians (default: 1 degree in radians = pi/180).

Example:

```
g = rgb2gray(rgb_image)
gx, gy = imgradients(g)
mag, grad_angle = magnitude_phase(gx,gy)
mag[mag .< 0.5] = 0.0  # Threshold magnitude image
thinned, subpix =  thin_edges_subpix(mag, grad_angle)
```
"""
thin_edges{T}(img::AbstractArray{T,2}, gradientangles::AbstractArray, border::AbstractString="replicate") =
    thin_edges_nonmaxsup(img, gradientangles, border)
thin_edges_subpix{T}(img::AbstractArray{T,2}, gradientangles::AbstractArray, border::AbstractString="replicate") =
    thin_edges_nonmaxsup_subpix(img, gradientangles, border)

# Code below is related to non-maximal suppression, and was ported to Julia from
# http://www.csse.uwa.edu.au/~pk/research/matlabfns/Spatial/nonmaxsup.m
# (Please conserve the original copyright below.)

# NONMAXSUP - Non-maxima suppression
#
# Usage:
#          (im,location) = nonmaxsup(img, gradientangles, radius);
#
# Function for performing non-maxima suppression on an image using
# gradient angles.  Gradient angles are assumed to be in radians.
#
# Input:
#   img - image to be non-maxima suppressed.
#
#   gradientangles - image containing gradient angles around each pixel in radians
#                    (-pi,pi)
#
#   radius  - Distance in pixel units to be looked at on each side of each
#             pixel when determining whether it is a local maxima or not.
#             This value cannot be less than 1.
#             (Suggested value about 1.2 - 1.5)
#
# Returns:
#   im        - Non maximally suppressed image.
#   location  - `Graphics.Point` image holding subpixel locations of edge
#               points.
#
# Notes:
#
# This function uses bilinear interpolation to estimate
# intensity values at ideal, real-valued pixel locations on each side of
# pixels to determine if they are local maxima.

# Copyright (c) 1996-2013 Peter Kovesi
# Centre for Exploration Targeting
# The University of Western Australia
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# The Software is provided "as is", without warranty of any kind.

# December  1996 - Original version
# September 2004 - Subpixel localization added
# August    2005 - Made Octave compatible
# October   2013 - Final thinning applied to binary image for Octave
#                  compatbility (Thanks to Chris Pudney)
# June      2014 - Ported (and modified significantly) to Julia (Kevin Squire)

import .Point

if !applicable(zero, Point)
    import Base.zero
    zero(::Type{Point}) = Point(0.0,0.0)
end

# Used to encode the sign, integral, and fractional components of
# an offset from a coordinate
immutable CoordOffset
    s::Int      # sign
    i::Int      # integer part
    f::Float64  # fractional part
end

CoordOffset(x::Float64) = ((frac,i) = modf(x); CoordOffset(sign(frac), round(Int, i), abs(frac)))
(-)(off::CoordOffset) = CoordOffset(-off.s,-off.i, off.f)
(*)(x::Number, off::CoordOffset) = x*(off.i + off.s*off.f)
(*)(off::CoordOffset, x::Number) = x*(off.i + off.s*off.f)
(+)(x::Number, off::CoordOffset) = x + off.i + off.s*off.f
(+)(off::CoordOffset, x::Number) = x + off.i + off.s*off.f

# Precalculate x and y offsets relative to centre pixel for each orientation angle
function _calc_discrete_offsets(θ, radius, transposed)

    θ_count = round(Int, 2π/θ)
    θ = 2π/θ_count
    angles = (0:θ_count)*θ

    # x and y offset of points at specified radius and angles
    # from each reference position.

    @compat if transposed
        # θ′ = -π/2 - θ
        xoffs = [CoordOffset(-x) for x in  radius * sin.(angles)]
        yoffs = [CoordOffset( y) for y in  radius * cos.(angles)]
    else
        xoffs = [CoordOffset( x) for x in  radius * cos.(angles)]
        yoffs = [CoordOffset(-y) for y in  radius * sin.(angles)]
    end

    return θ, xoffs, yoffs
end

_discretize_angle(angle::AbstractFloat, invθ) =
    angle < 0 ? round(Int, (angle + 2π)*invθ)+1 : round(Int, angle*invθ)+1

# Interpolate the value of an offset from a particular pixel
#
# Returns (interpolated value, min_value of adjacent pixels in direction of offset)
#
# The second value is made available to eliminate double edges; if the value at
# (x,y) is less than the value or values adjacent to it in the direction of the
# gradient (xoff,yoff), then it is not a local maximum

function _interp_offset(img::AbstractArray, x::Integer, y::Integer, xoff::CoordOffset, yoff::CoordOffset, Ix, Iy, pad)
    fx = Ix[x + xoff.i + pad]
    fy = Iy[y + yoff.i + pad]
    cx = Ix[x + xoff.i + xoff.s + pad]
    cy = Iy[y + yoff.i + yoff.s + pad]

    tl = img[fy,fx]    # Value at bottom left integer pixel location.
    tr = img[fy,cx]    # bottom right
    bl = img[cy,fx]    # top left
    br = img[cy,cx]    # top right

    upperavg = tl + xoff.f * (tr - tl)  # Now use bilinear interpolation to
    loweravg = bl + xoff.f * (br - bl)  # estimate value at x,y

    min_adjacent = (fx == x) & (fy == y) ? min(tr,bl) : tl

    return (upperavg + yoff.f * (loweravg - upperavg), min_adjacent)
end

# Core edge thinning algorithm using nonmaximal suppression
function thin_edges_nonmaxsup_core!{T}(out::AbstractArray{T,2}, location::AbstractArray{Point,2},
                                       img::AbstractArray{T,2}, gradientangles, radius, border, theta)
    calc_subpixel = !isempty(location)

    # Error checking
    size(img) == size(gradientangles) == size(out) || error("image, gradient angle, and output image must all be the same size")
    calc_subpixel && size(location) != size(img) && error("subpixel location has a different size than the input image")
    radius < 1.0 && error("radius must be >= 1")

    # Precalculate x and y offsets relative to centre pixel for each orientation angle
    transposed = spatialorder(img)[1] == "x"
    θ, xoffs, yoffs = _calc_discrete_offsets(theta, radius, transposed)
    iθ = 1/θ

    # Indexes to use for border handling
    pad = ceil(Int, radius)
    Ix = Images.padindexes(img, 2, pad, pad, border)
    Iy = Images.padindexes(img, 1, pad, pad, border)

    # Now run through the image interpolating grey values on each side
    # of the centre pixel to be used for the non-maximal suppression.

    (height,width) = size(img)

    for x = 1:width, y = 1:height
        (c = img[y,x]) == 0 && continue  # For thresholded images

        or = _discretize_angle(gradientangles[y,x],iθ)   # Disretized orientation
        v1, n1 = _interp_offset(img, x, y, xoffs[or], yoffs[or], Ix, Iy, pad)

        if (c > v1) & (c >= n1) # We need to check the value on the other side...
            v2, n2 = _interp_offset(img, x, y, -xoffs[or], -yoffs[or], Ix, Iy, pad)

            if (c > v2) & (c >= n2)  # This is a local maximum.
                                     # Record value in the output image.
                if calc_subpixel
                    # Solve for coefficients of parabola that passes through
                    # [-1, v2]  [0, img] and [1, v1].
                    # v = a*r^2 + b*r + c

                    # c = img[y,x]
                    a = (v1 + v2)/2 - c
                    b = a + c - v2

                    # location where maxima of fitted parabola occurs
                    r = -b/2a
                    location[y,x] = transposed ? Point(y + r*yoffs[or], x + r*xoffs[or]) :
                                                 Point(x + r*xoffs[or], y + r*yoffs[or])

                    if T<:AbstractFloat
                        # Store the interpolated value
                        out[y,x] = a*r^2 + b*r + c
                    else
                        out[y,x] = c
                    end
                else
                    out[y,x] = c
                end
            end
        end
    end

    out
end


# Main function call when subpixel location of edges is not needed
function thin_edges_nonmaxsup!{A<:AbstractArray,B<:AbstractArray}(out::A, img::A, gradientangles::B, border::AbstractString="replicate";
                                                                  radius::Float64=1.35, theta=pi/180)
    properties(out) != properties(img) && error("Input and output arrays must have the same properties")
    thin_edges_nonmaxsup_core!(data(out), Array(Point,(0,0)), img, gradientangles, radius, border, theta)
    out
end

function thin_edges_nonmaxsup{T}(img::AbstractArray{T,2}, gradientangles::AbstractArray, border::AbstractString="replicate";
                                 radius::Float64=1.35, theta=pi/180)
    (height,width) = size(img)
    out = zeros(T, height, width)
    thin_edges_nonmaxsup_core!(out, Array(Point,(0,0)), img, gradientangles, radius, border, theta)
    copyproperties(img, out)
end

# Main function call when subpixel location of edges is desired
function thin_edges_nonmaxsup_subpix!{A<:AbstractArray, B<:AbstractArray, C<:AbstractArray}(out::A, location::B, img::A, gradientangles::C,
                                     border::AbstractString="replicate"; radius::Float64=1.35, theta=pi/180)
    properties(out) != properties(img) && error("Input and output arrays must have the same properties")
    eltype(location) != Point && error("Preallocated subpixel location array/image must have element type Graphics.Point")

    thin_edges_nonmaxsup_core!(data(out), data(location), img, gradientangles, radius, border, theta)
    img, location
end

function thin_edges_nonmaxsup_subpix{T}(img::AbstractArray{T}, gradientangles::AbstractArray,
                                        border::AbstractString="replicate"; radius::Float64=1.35, theta=pi/180)
    (height,width) = size(img)
    out = zeros(T, height, width)
    location = zeros(Point, height, width)
    thin_edges_nonmaxsup_core!(out, location, img, gradientangles, radius, border, theta)

    copyproperties(img, out), copyproperties(img, location)
end

"""
```
canny_edges = canny(img, sigma = 1.4, upperThreshold = 0.80, lowerThreshold = 0.20)
```

Performs Canny Edge Detection on the input image.

Parameters :

  sigma :           Specifies the standard deviation of the gaussian filter
  upperThreshold :  Upper bound for hysteresis thresholding
  lowerThreshold :  Lower bound for hysteresis thresholding
  astype :          Specifies return type of result
  percentile :      Specifies if upperThreshold and lowerThreshold should be used
                    as quantiles or absolute values

"""
function canny{T}(img::AbstractArray{T, 2}, sigma::Number = 1.4, upperThreshold::Number = 0.90, lowerThreshold::Number = 0.10; percentile::Bool = true)
    img_gray = convert(Image{Images.Gray{U8}}, img)
    img_grayf = imfilter_gaussian(img_gray, [sigma,sigma])
    img_grad_x, img_grad_y = imgradients(img_grayf, "sobel")
    img_mag, img_phase = magnitude_phase(img_grad_x, img_grad_y)
    img_nonMaxSup = thin_edges_nonmaxsup(img_mag, img_phase)
    if percentile == true
        upperThreshold = StatsBase.percentile(img_nonMaxSup[:], upperThreshold * 100)
        lowerThreshold = StatsBase.percentile(img_nonMaxSup[:], lowerThreshold * 100)
    end
    img_thresholded = hysteresis_thresholding(img_nonMaxSup, upperThreshold, lowerThreshold)
    edges = map(i -> i < 0.9 ? zero(Gray{U8}) : one(Gray{U8}), img_thresholded)
    edges
end


function hysteresis_thresholding{T}(img_nonMaxSup::AbstractArray{T, 2}, upperThreshold::Number, lowerThreshold::Number)
    img_thresholded = map(i -> i > lowerThreshold ? i > upperThreshold ? 1.0 : 0.5 : 0.0, img_nonMaxSup)
    queue = CartesianIndex{2}[]
    R = CartesianRange(size(img_thresholded))

    I1, Iend = first(R), last(R)
    for I in R
      if img_thresholded[I] == 1.0
        img_thresholded[I] = 0.9
        push!(queue, I)
        while !isempty(queue)
          q_top = shift!(queue)
          for J in CartesianRange(max(I1, q_top - I1), min(Iend, q_top + I1))
            if img_thresholded[J] == 1.0 || img_thresholded[J] == 0.5
              img_thresholded[J] = 0.9
              push!(queue, J)
            end
          end
        end
      end
    end
    img_thresholded
end
0
