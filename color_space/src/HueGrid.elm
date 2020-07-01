module HueGrid exposing (gridForHue, sceneRadius)

import Angle exposing (Angle)
import Axis3d
import Color exposing (Color)
import Length
import Munsell exposing (ColorDict)
import Point3d
import Scene3d
import World exposing (WorldEntity, WorldEntityList)



---- CONSTANTS ----
{- All these are measured in centimeters. -}


cylinderRadius : Float
cylinderRadius =
    45


cubeSize : Float
cubeSize =
    40


x0 : Float
x0 =
    120


spacing : Float
spacing =
    60


fanCount : Int
fanCount =
    8


fanAngle : Float
fanAngle =
    180.0 / toFloat (fanCount - 1)


zForValue : Int -> Float
zForValue value =
    toFloat (value - 5) * spacing


sceneRadius : Float
sceneRadius =
    x0 + (8 * spacing) + cubeSize



---- HUE GRID CUBES ----


gridForHue : ColorDict -> Int -> WorldEntityList
gridForHue colors hue =
    let
        cylinders =
            Munsell.valueRange
                |> List.map cylinderForValue

        cubes =
            gridCubes colors hue
    in
    cylinders ++ cubes


cylinderForValue : Int -> WorldEntity
cylinderForValue value =
    let
        z =
            zForValue value

        origin =
            Point3d.centimeters 0 0 z

        color =
            Munsell.neutralColor value
    in
    World.matteCylinderAt origin
        { radius = Length.centimeters cylinderRadius
        , length = Length.centimeters cubeSize
        }
        color


gridCubes : ColorDict -> Int -> WorldEntityList
gridCubes colors hue =
    List.range 0 ((fanCount // 2) - 1)
        |> List.foldl
            (\i acc ->
                let
                    thetaRight =
                        toFloat i * fanAngle

                    thetaLeft =
                        toFloat (fanCount - i - 1) * fanAngle

                    hueRight =
                        modBy 1000 (hue + (i * 25))

                    hueLeft =
                        modBy 1000 (hue + 500 + (i * 25))
                in
                acc
                    ++ cubesForHue colors hueRight (Angle.degrees thetaRight)
                    ++ cubesForHue colors hueLeft (Angle.degrees thetaLeft)
            )
            []


cubesForHue : ColorDict -> Int -> Angle -> WorldEntityList
cubesForHue colors hue angle =
    Munsell.valueRange
        |> List.foldl (\value acc -> cubesForHV colors hue value angle ++ acc) []


cubesForHV : ColorDict -> Int -> Int -> Angle -> WorldEntityList
cubesForHV colors hue value angle =
    Munsell.chromaRange
        |> List.foldl
            (\chroma acc ->
                case cubeInGamut colors hue value chroma angle of
                    Just cube ->
                        cube :: acc

                    Nothing ->
                        acc
            )
            []


cubeInGamut : ColorDict -> Int -> Int -> Int -> Angle -> Maybe WorldEntity
cubeInGamut colors hue value chroma angle =
    Munsell.findColor colors hue value chroma
        |> Maybe.andThen (\{ color } -> Just (cubeWithColor color hue value chroma angle))


cubeWithColor : Color -> Int -> Int -> Int -> Angle -> WorldEntity
cubeWithColor color _ value chroma angle =
    let
        x =
            x0 + toFloat ((chroma // 2) - 1) * spacing

        z =
            zForValue value

        origin =
            Point3d.centimeters x 0 z
    in
    World.matteCubeAt origin (Length.centimeters cubeSize) color
        |> Scene3d.rotateAround Axis3d.z angle
