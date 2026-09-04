# iridium

a physically based gpu accelerated path tracer

---

for you to actually use it, clone this repo, download specifically love 12 from the love2d github actions and in a terminal inside the project folder run lovec ./ and there you go.

## keybinds

|keybind |what it does |
|--------|------------|
|Enter   | opens the scene file picker|
|Space   | pauses/starts rendering|
|\       | opens the environment exr file picker|
|Ctrl + S| saves the current render state as an exr file on the working directory|
|Alt + S | saves the current depth buffer as an exr file on the working directory|
|W       | moves forward|
|A       | moves to the left|
|S       | moves backwards|
|D       | moves to the right|
|E       | moves up|
|Q       | moves down|
|Mouse 2 hold| pans camera|
|Shift + Mouse 1| focus the camera on the mouse position|

its made in love 12 and its just as fast as you expect it to be

also heres some renders made with it

<img width="1920" height="1080" alt="ring 2" src="https://github.com/user-attachments/assets/1b43cc39-dd66-4591-90aa-1d8c92e1cadd" />
<img width="1920" height="1080" alt="ring 1" src="https://github.com/user-attachments/assets/200f2f0f-5c23-4ad7-9f72-587f74aeb5fa" />
<img width="1920" height="1080" alt="khronos glass candle rainbow" src="https://github.com/user-attachments/assets/15811b0f-d184-43c7-a174-fab23392c2eb" />
<img width="1920" height="1080" alt="liminar" src="https://github.com/user-attachments/assets/5a2d11f0-ac1d-4094-a017-944d8be72c35" />
<img width="1280" height="720" alt="khronos chess 2" src="https://github.com/user-attachments/assets/e87d254d-ac36-474f-aacb-50677d1e9875" />
<img width="1280" height="720" alt="glass cornell" src="https://github.com/user-attachments/assets/1c66cd61-5a16-4302-b83a-3b507a8198cc" />
<img width="1280" height="720" alt="khronos ior balls" src="https://github.com/user-attachments/assets/3b1dc5d2-434e-48c7-a703-2b60e79d0239" />
<img width="1920" height="1080" alt="hq khronos chess" src="https://github.com/user-attachments/assets/05a6004a-f302-42a8-8fcd-3e3563300de5" />
<img width="1670" height="540" alt="wide mclaren filmic" src="https://github.com/user-attachments/assets/003478a6-f69f-486e-b499-b5f150fb6b12" />
<img width="1280" height="720" alt="khronos glass holder dof" src="https://github.com/user-attachments/assets/6b25e902-2240-4e91-89a9-5ee567d3f96e" />
<img width="960" height="544" alt="khronos ior balls dof" src="https://github.com/user-attachments/assets/70574ce7-8012-4687-86f2-2ab6fbb971f6" />
<img width="1920" height="1080" alt="cornell lens" src="https://github.com/user-attachments/assets/4a8bfed9-8137-4ef1-b7b5-72875323df22" />
<img width="2558" height="1600" alt="Screenshot 2026-08-29 140743" src="https://github.com/user-attachments/assets/68272b89-a044-432e-a6c5-89f1d8924fae" />



# References
* GLSL PathTracer (https://github.com/knightcrawler25/GLSL-PathTracer/) for validation and some of the scenes
* Pixar RenderMan for bokeh and anamorphic validation
* Sebastian Lague (https://github.com/SebLague/) for inspiration, huge source of knowledge from all his Coding Adventures
* Ray Tracing in One Weekend (https://github.com/petershirley/raytracinginoneweekend) for dielectrics and inspiration
* Love2D for making this possible at all
* Zellicious (https://github.com/Zellicious) for making me have the idea :>
