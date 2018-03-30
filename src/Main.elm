module Main exposing (..)

import AnimationFrame
import Dict exposing (Dict)
import Html exposing (Html, div, p, text, input)
import Html.Attributes as HA exposing (type_, value, src, width, height, style, checked)
import Html.Events exposing (onClick, onInput)
import WebGL exposing (Mesh, Shader)
import Math.Matrix4 as Mat4 exposing (Mat4, transform, translate, rotate)
import Math.Vector3 as Vec3 exposing (Vec3, vec3)
import Time exposing (Time)
import Task
import Window
import MunsellData
    exposing
        ( MunsellColor
        , ColorDict
        , numericFromString
        , findColor
        , loadColors
        )


---- WEBGL TYPES ----


type alias Color =
    Vec3


type alias Vertex =
    { position : Vec3
    , color : Color
    }


type alias Uniforms =
    { perspective : Mat4 }


{-| List of 4 corner points (top face) * 2
List.length cube == 2 * 4
-}
type alias Cube =
    List Vertex


{-| List of center point and 'circlePoints' points on circumference (top face) * 2
List.length cylinder = 2 * (circlePoints + 1)
-}
type alias Cylinder =
    List Vertex



---- MODEL ----


{-| value is integer range 1 to 9
0 = black
10 = white
-}
type alias Model =
    { window : Window.Size
    , colors : ColorDict
    , value : String
    , frozen : Bool
    , theta : Float
    , wheelMeshes : Dict Int (Mesh Vertex)
    }


init : ( Model, Cmd Msg )
init =
    let
        colors =
            loadColors
    in
        ( { window = Window.Size 800 800
          , colors = colors
          , value = "7"
          , frozen = True
          , theta = 0.5 * Basics.pi
          , wheelMeshes = buildWheelMeshes colors
          }
        , Task.perform Resize Window.size
        )


colorValue : Model -> Int
colorValue model =
    String.toInt model.value |> numericFromString 7



---- UPDATE ----


type Msg
    = Resize Window.Size
    | FrameTick Time
    | ValueInput String
    | Freeze


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Resize size ->
            ( { model | window = size }, Cmd.none )

        FrameTick dt ->
            let
                model_ =
                    case model.frozen of
                        True ->
                            model

                        False ->
                            { model | theta = model.theta + (dt / 1000.0) }
            in
                ( model_, Cmd.none )

        ValueInput newValue ->
            ( { model | value = newValue }, Cmd.none )

        Freeze ->
            ( { model | frozen = not model.frozen }, Cmd.none )



---- VIEW ----


view : Model -> Html Msg
view model =
    [ p [] [ text "Value" ]
    , input
        [ type_ "range"
        , HA.min "1"
        , HA.max "9"
        , value model.value
        , onInput ValueInput
        ]
        []
    , p [] [ text "Freeze" ]
    , input
        [ type_ "checkbox"
        , checked model.frozen
        , onClick Freeze
        ]
        []
    , viewWheelMeshes model.wheelMeshes model.window model.theta (colorValue model)
    ]
        |> div []


viewWheelMeshes : Dict Int (Mesh Vertex) -> Window.Size -> Float -> Int -> Html Msg
viewWheelMeshes meshes window theta value =
    let
        x =
            cos theta

        y =
            0 - sin theta

        w =
            toFloat window.width

        h =
            toFloat window.height
    in
        WebGL.toHtml
            [ width window.width
            , height window.height
            , style [ ( "display", "block" ) ]
            ]
            (List.range 1 value
                |> List.map (\v -> Dict.get v meshes)
                |> List.foldl
                    (\m acc ->
                        case m of
                            Just mesh ->
                                WebGL.entity
                                    vertexShader
                                    fragmentShader
                                    mesh
                                    { perspective = perspective w h x y }
                                    :: acc

                            Nothing ->
                                acc
                    )
                    []
            )



---- SPACE CONSTANTS ----


circleRadius : Float
circleRadius =
    90.0


circlePoints : Int
circlePoints =
    30


cylinderPoints : Int
cylinderPoints =
    2 * (circlePoints + 1)


cubePoints : Int
cubePoints =
    8


bandUnit : Float
bandUnit =
    45.0


valueUnit : Float
valueUnit =
    90.0


scaleFactor : Float
scaleFactor =
    circleRadius + 5.0 + (7.5 * bandUnit)


scaledUnit : Float
scaledUnit =
    40.0 / scaleFactor


valueDepth : Int -> Float
valueDepth value =
    toFloat (5 - value) * valueUnit / scaleFactor


lookFrom : Float
lookFrom =
    6



---- SPACE UTILITY FUNCTIONS ----


{-| integers, 0 to 975
0 = 10RP
25 = 2.5R
50 = 5R
75 = 7.5R
100 = 10R
etc.
-}
hueRange : List Int
hueRange =
    List.range 0 39
        |> List.map ((*) 25)


{-| even integers, 2 to 16
-}
chromaRange : List Int
chromaRange =
    List.range 1 8
        |> List.map ((*) 2)



---- COLOR WHEEL CIRCLES ----


circumPoint : Color -> Float -> Int -> Vertex
circumPoint color z i =
    let
        t =
            Basics.pi * toFloat i * (2.0 / toFloat circlePoints)

        ( x, y ) =
            ( sin t * circleRadius / scaleFactor, cos t * circleRadius / scaleFactor )
    in
        Vertex (vec3 x y z) color


cylinderVertices : Int -> Cylinder
cylinderVertices value =
    let
        grayValue =
            (toFloat value) / 10.0

        color =
            vec3 grayValue grayValue grayValue

        zTop =
            valueDepth value - (scaledUnit / 2)

        zBottom =
            valueDepth value + (scaledUnit / 2)

        circumTop =
            List.range 1 circlePoints
                |> List.map (circumPoint color zTop)

        circumBottom =
            List.range 1 circlePoints
                |> List.map (circumPoint color zBottom)
    in
        List.concat
            [ Vertex (vec3 0 0 zTop) color :: circumTop
            , Vertex (vec3 0 0 zBottom) color :: circumBottom
            ]



---- COLOR WHEEL RECTANGLES ----


colorCubeVertices : ColorDict -> Int -> List Cube
colorCubeVertices colors value =
    List.foldl (\hue acc -> (makeColorCubesForHue colors hue value) ++ acc) [] hueRange


makeColorCubesForHue : ColorDict -> Int -> Int -> List Cube
makeColorCubesForHue colors hue value =
    List.foldl
        (\chroma acc ->
            case makeColorCube colors hue value chroma of
                Just rect ->
                    rect :: acc

                Nothing ->
                    acc
        )
        []
        chromaRange


makeColorCube : ColorDict -> Int -> Int -> Int -> Maybe Cube
makeColorCube colors hue value chroma =
    case colorRgb colors hue value chroma of
        Just color ->
            let
                xf =
                    xfColorCube hue value chroma

                ( dx2, dy2, dz2 ) =
                    dimColorCube2 hue value chroma
            in
                Just <|
                    [ Vertex (transform xf (vec3 -dx2 -dy2 dz2)) color
                    , Vertex (transform xf (vec3 -dx2 dy2 dz2)) color
                    , Vertex (transform xf (vec3 dx2 dy2 dz2)) color
                    , Vertex (transform xf (vec3 dx2 -dy2 dz2)) color
                    , Vertex (transform xf (vec3 -dx2 -dy2 -dz2)) color
                    , Vertex (transform xf (vec3 -dx2 dy2 -dz2)) color
                    , Vertex (transform xf (vec3 dx2 dy2 -dz2)) color
                    , Vertex (transform xf (vec3 dx2 -dy2 -dz2)) color
                    ]

        Nothing ->
            Nothing


dimColorCube2 : Int -> Int -> Int -> ( Float, Float, Float )
dimColorCube2 _ _ chroma =
    let
        dx2 =
            case chroma of
                2 ->
                    0.16 * scaledUnit

                4 ->
                    0.25 * scaledUnit

                6 ->
                    0.33 * scaledUnit

                8 ->
                    0.4 * scaledUnit

                10 ->
                    0.5 * scaledUnit

                12 ->
                    0.5 * scaledUnit

                _ ->
                    0.67 * scaledUnit
    in
        ( dx2, 0.5 * scaledUnit, 0.5 * scaledUnit )


colorRgb : ColorDict -> Int -> Int -> Int -> Maybe Color
colorRgb colors hue value chroma =
    case findColor colors hue value chroma of
        Ok mc ->
            Just <| vec3 mc.red mc.green mc.blue

        Err err ->
            Nothing


xfColorCube : Int -> Int -> Int -> Mat4
xfColorCube hue value chroma =
    let
        theta =
            (toFloat hue) * Basics.pi * (2.0 / 1000.0)

        band =
            toFloat (chroma // 2) - 0.5

        y =
            (circleRadius + 5.0 + (band * bandUnit)) / scaleFactor

        z =
            valueDepth value
    in
        Mat4.identity
            |> rotate theta (vec3 0 0 1)
            |> translate (vec3 0 y z)



---- COLOR WHEEL MESH ----


buildWheelMeshes : ColorDict -> Dict Int (Mesh Vertex)
buildWheelMeshes colors =
    List.range 1 9
        |> List.map (\value -> ( value, buildWheelMeshForValue colors value ))
        |> Dict.fromList


buildWheelMeshForValue : ColorDict -> Int -> Mesh Vertex
buildWheelMeshForValue colors value =
    let
        cylinder =
            cylinderVertices value

        cubes =
            colorCubeVertices colors value
    in
        wheelMesh cylinder cubes


cubeVertexOrder : List ( Int, Int, Int )
cubeVertexOrder =
    [ -- front
      ( 0, 1, 2 )
    , ( 2, 3, 0 )
    , -- right
      ( 1, 5, 6 )
    , ( 6, 2, 1 )
    , -- back
      ( 7, 6, 5 )
    , ( 5, 4, 7 )
    , -- left
      ( 4, 0, 3 )
    , ( 3, 7, 4 )
    , -- bottom
      ( 4, 5, 1 )
    , ( 1, 0, 4 )
    , -- top
      ( 3, 2, 6 )
    , ( 6, 7, 3 )
    ]


singleColorCubeIndices : Int -> Int -> List ( Int, Int, Int )
singleColorCubeIndices offset i =
    let
        base =
            cubePoints * i + offset
    in
        cubeVertexOrder
            |> List.map
                (\( v1, v2, v3 ) ->
                    ( base + v1, base + v2, base + v3 )
                )


colorCubeIndices : Int -> List Cube -> List ( Int, Int, Int )
colorCubeIndices offset cubes =
    List.indexedMap (\i _ -> singleColorCubeIndices offset i) cubes
        |> List.concat


cylinderIndices : List ( Int, Int, Int )
cylinderIndices =
    let
        top =
            List.range 1 circlePoints
                |> List.map
                    (\i ->
                        ( 0
                        , i
                        , if i < circlePoints then
                            i + 1
                          else
                            1
                        )
                    )

        sides =
            List.range 1 circlePoints
                |> List.map
                    (\i ->
                        if i < circlePoints then
                            [ ( i, i + circlePoints + 1, i + circlePoints + 2 )
                            , ( i + circlePoints + 2, i + 1, i )
                            ]
                        else
                            [ ( circlePoints, 2 * circlePoints + 1, circlePoints + 2 )
                            , ( circlePoints + 2, 1, circlePoints )
                            ]
                    )
                |> List.concat

        bottom =
            List.range (circlePoints + 1) (2 * circlePoints + 1)
                |> List.reverse
                |> List.map
                    (\i ->
                        ( circlePoints + 1
                        , i
                        , if i > circlePoints then
                            i - 1
                          else
                            2 * circlePoints + 1
                        )
                    )
    in
        List.concat [ top, sides, bottom ]


wheelMesh : Cylinder -> List Cube -> Mesh Vertex
wheelMesh cylinder cubes =
    WebGL.indexedTriangles
        (List.concat (cylinder :: cubes))
        (List.concat [ cylinderIndices, colorCubeIndices cylinderPoints cubes ])


perspective : Float -> Float -> Float -> Float -> Mat4
perspective width height x y =
    let
        eye =
            vec3 x 0 y
                |> Vec3.normalize
                |> Vec3.scale 6
    in
        Mat4.mul
            (Mat4.makePerspective 30 (width / height) 0.01 100)
            (Mat4.makeLookAt eye (vec3 0 0 0) Vec3.j)


vertexShader : Shader Vertex Uniforms { vcolor : Vec3 }
vertexShader =
    [glsl|
        attribute vec3 position;
        attribute vec3 color;
        uniform mat4 perspective;
        varying vec3 vcolor;
        void main () {
            gl_Position = perspective * vec4(position, 1.0);
            vcolor = color;
        }
    |]


fragmentShader : Shader {} Uniforms { vcolor : Vec3 }
fragmentShader =
    [glsl|
        precision mediump float;
        varying vec3 vcolor;
        void main () {
            gl_FragColor = vec4(vcolor, 1.0);
        }
    |]



---- PROGRAM ----


main : Program Never Model Msg
main =
    Html.program
        { view = view
        , init = init
        , update = update
        , subscriptions = subscriptions
        }


subscriptions : Model -> Sub Msg
subscriptions model =
    case model.frozen of
        True ->
            Window.resizes Resize

        False ->
            Sub.batch
                [ Window.resizes Resize
                , AnimationFrame.diffs FrameTick
                ]
