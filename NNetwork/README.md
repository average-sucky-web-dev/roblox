# Neural networks

This folder contains helper functions and a module script allowing for the creation of simple computer vision neural networks.

### HOW TO USE


**Step one:** Load NNetwork.lua
```lua
local NNetwork = require(script.Parent.NNetwork) -- obviously replace with whereever NNetwork is
```


**Step two:** Create your NNetwork object
```lua
local AI = NNetwork.new(paramtable)
```


**Step three:** Submit your dataset to the network in the format of {{X: {}, Y: {}}
```lua
AI:train(dataset, LR, iterations)
```


**Step four:** You now have a neural network!
```lua
local output = AI:predict(X)
```

Run demo.lua for a demo!


<sub>This library is currently designed for computer vision, using the softplus activator and the soft/argmax algorithm to calculate. Future support will come allowing for dynamic algorithms (and maybe presets!) but for now this library is rather limited.</sub>

<sub>oh yeah made by tycoonplayer on dsc cause i forgot to include credit for the ppl reading my application</sub>
