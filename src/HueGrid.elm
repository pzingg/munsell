module HueGrid exposing (buildMesh)

import WebGL
import Math.Matrix4 as Mat4 exposing (Mat4, scale3, translate3)
import Math.Vector3 as Vec3 exposing (Vec3, vec3)
import Geometry as Geom
    exposing
        ( Solid
        , AppMesh
        , makeColor
        , makeCube
        , toMesh
        )
import Munsell exposing (ColorDict, hueRange, chromaRange, valueRange)


---- CONSTANTS ----


cubeSize : Float
cubeSize =
    40


xySpacing : Float
xySpacing =
    50


zSpacing : Float
zSpacing =
    90



---- HUE GRID CUBES ----


cubesForHue : ColorDict -> Int -> List Solid
cubesForHue colors hue =
    List.foldl (\value acc -> (cubesForHV colors hue value) ++ acc) [] valueRange


cubesForHV : ColorDict -> Int -> Int -> List Solid
cubesForHV colors hue value =
    List.foldl
        (\chroma acc ->
            case cubeInGamut colors hue value chroma of
                Just rect ->
                    rect :: acc

                Nothing ->
                    acc
        )
        []
        chromaRange


cubeInGamut : ColorDict -> Int -> Int -> Int -> Maybe Solid
cubeInGamut colors hue value chroma =
    case makeColor colors hue value chroma of
        Just color ->
            Just (cubeWithColor color hue value chroma)

        Nothing ->
            Nothing


cubeWithColor : Vec3 -> Int -> Int -> Int -> Solid
cubeWithColor color hue value chroma =
    xfCube hue value chroma
        |> makeCube color


xfCube : Int -> Int -> Int -> Mat4
xfCube _ value chroma =
    let
        x =
            (toFloat ((chroma // 2) - 1)) * xySpacing

        y =
            (toFloat (value - 5)) * xySpacing
    in
        Mat4.identity
            |> translate3 x y 0
            |> scale3 cubeSize cubeSize cubeSize


buildMesh : ColorDict -> Int -> AppMesh
buildMesh colors hue =
    cubesForHue colors hue
        |> toMesh
