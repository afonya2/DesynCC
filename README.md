# DesynCC
An async/await library for CC:Tweaked

## Installing
Run `wget run https://raw.githubusercontent.com/afonya2/DesynCC/refs/heads/main/installer.lua` to install DesynCC.

## Installing tests and running them
Run `wget run https://raw.githubusercontent.com/afonya2/DesynCC/refs/heads/main/installer.lua test` to install tests.

You can run the tests by running `desyncc/test/runTests.lua`

Each test will print what the expected output is.

## Contributing
This repository is under the MIT license so you're free to edit/modify the code.
If you plan to make a pull-request to this repository, follow these rules:

- All pull requests must target the `dev` branch
- Pull requests opened against `main` may be closed or asked to be retargeted
- Follow indentation (4 spaces)
- Do not make "troll" commits that don't serve any real purpose
- One feature or fix per pull request, you can contain multiple smaller fixes in one PR
- Use clear commit messages that describe what changed
- Reference related issues when applicable
- For large changes or new features, please open an issue first to discuss the idea
- Make sure each test returns the expected output before submitting a PR

## Documentation
### Getting started
To get started [install](#installing) DesynCC. Create a new file and paste the following code into it:
```lua
local desyncc = require("desyncc.main")

local sys = desyncc:new()

local function main()
    -- Insert your code here
end

sys:start(main)
```
This will setup DesynCC and run the `main` function as a task. You can create as many tasks as you want, and they will all run concurrently.
You can create a task by running `sys:task(function() ... end)`. This will create a new task that runs the provided function.

### getVersion()
Returns the version of DesynCC.
> [!IMPORTANT]
> This is the only method that is a static method. You can call it with `desyncc.getVersion()`.

**Parameters**

**Outputs**
- string: The version of DesynCC

**Example**
```lua
print("DesynCC version: ", desyncc.getVersion())
```

> [!NOTE]
> All of the following functions are methods of a desyncc class. If you follow the example above, you need to call them with `sys:method(...)`.

### promise(func: function): Promise Controller
Creates a new promise and returns controller functions for it. Used to create async functions that need to wait for something that's non-blocking like an event. See [events](#events)
> [!IMPORTANT]
> If a promise is rejected without it having a .catch() function, it will throw an error. If a promise is resolved without it having a .after() function, it will do nothing. Awaiting for a promise that has been resolved will return the values passed to the resolve function. Awaiting for a promise that has been rejected will throw an error.
> [!IMPORTANT]
> Returning anything in the function body will do nothing. You must use the resolve and reject functions to resolve or reject the promise.

**Parameters**
- func: function: The function to execute to resolve the promise.

**Outputs**
- table: The promise controller, which contains the following functions:
    - .after(func: function): Used to register a callback function that will be ran when the promise is resolved. The callback function is not ran as a different task. Thus it blocks the current task from executing.
    - .catch(func: function): Used to register a callback function that will be ran when the promise is rejected. The callback function is not ran as a different task. Thus it blocks the current task from executing.
    - .await(): Used to wait for the promise to be resolved or rejected. If the promise is resolved, it returns the values passed to the resolve function. If the promise is rejected, it throws an error.
    - .result(): Used to get the result(s) of the promise. It returns "resolved"/"rejected" as the first value, and then the values passed to the resolve/reject function. If the promise is not yet resolved or rejected, it returns nil.
    - .status(): Used to get the coroutine status of the promise's task. It returns "running", "suspended", or "dead". If the task cannot be found, it returns nil.
    - .id(): Used to get the id of the promise.

**Example**
```lua
local function asyncFunc()
    return sys:promise(function(resolve, reject)
        -- Do some async stuff here, then call resolve(...) or reject(...)
    end)
end

local function main()
    local promise = asyncFunc()
    local result = promise:await()
    print("Got result: ", result)
end
```

### async(func: function): function
Creates a new async function. An async function is just a function that returns a promise. If the function body returns, the promise gets resolved.
> [!IMPORTANT]
> If the function errors, the promise gets rejected. For functions that require waiting for non-blocking stuff, use the [promise](#taskfunc-function-promise-controller) function instead.
> [!WARNING]
> You should avoid returning a new promise inside the async function. If you need to do that, use the [promise](#taskfunc-function-promise-controller) function instead.


**Parameters**
- func: function: The function to execute.

**Outputs**
- function: The async function, which when called, returns a Promise Controller. See [promise](#taskfunc-function-promise-controller).

**Example**
```lua
local asyncFunc = sys:async(function()
    -- Do some async stuff here, then call resolve(...) or reject(...)
end)

local function main()
    local promise = asyncFunc()
    local result = promise:await()
    print("Got result: ", result)
end
```

### task(func: function): Promise Controller
Creates a new task that runs independently of the main task. It creates an async function and executes it immediately. It returns the promise controller of the async function, so you can wait for it to finish or get its result.

**Parameters**
- func: function: The function to execute.

**Outputs**
- table: The promise controller, for more information, see [promise](#taskfunc-function-promise-controller).

**Example**
```lua
local function main()
    sys:task(function()
        os.sleep(2)
        print("This function runs independently!")
    end)
    print("Something")
end
```

### timeout(func: function, timeout: number): Promise Controller
Creates a new task that runs after the specified timeout. It creates a task that waits until the given timeout, then it runs the function provided. It returns the promise controller of the async function, so you can wait for it to finish or get its result.

**Parameters**
- func: function: The function to execute.
- timeout: number: The timeout in milliseconds.

**Outputs**
- table: The promise controller, for more information, see [promise](#taskfunc-function-promise-controller).

**Example**
```lua
local function main()
    sys:timeout(function()
        print("This function runs after the timeout!")
    end, 2000)
    print("Something")
end
```

### interval(func: function, interval: number): Interval Controller
Creates a new task that runs periodically the specified timeout. It creates a task that waits until the given timeout, then it runs the function provided. It returns an interval controller.
> [!WARNING]
> Awaiting this promise is pointless, because it will only finish whenever the interval is removed. To remove the interval, call the .remove() function on the interval controller.

**Parameters**
- func: function: The function to execute.
- interval: number: The interval in milliseconds.

**Outputs**
- table: The interval controller. The interval controller is based on the [Promise Controller](#taskfunc-function-promise-controller) with the following additional function:
    - .remove(): Used to remove the interval. After calling this function, the interval will no longer run.

**Example**
```lua
local function main()
    sys:interval(function()
        print("This function runs periodically!")
    end, 2000)
    print("Something")
end
```

### on(event: string, func: function)
Creates an event listener for the specified event. It creates a task for every callback function whenever an event is fired. So callback functions run independently of the main task.

**Parameters**
- event: string: The event to listen for.
- func: function: The callback function to run when the event is fired.

**Outputs**

**Example**
```lua
local function main()
    sys:on("modem_message", function(side, channel, replyChannel, message, distance)
        print(("Message received on side %s on channel %d (reply to %d) from %f blocks away with message %s"):format(
            side, channel, replyChannel, distance, tostring(message)
        ))
    end)
end
```

### once(event: string, func: function)
Creates an event listener for the specified event. It creates a task for every callback function whenever an event is fired. So callback functions run independently of the main task. This callback will only fire once. After the event is fired and the callback function is executed, the event listener will be removed.

**Parameters**
- event: string: The event to listen for.
- func: function: The callback function to run when the event is fired.

**Outputs**

**Example**
```lua
local function main()
    sys:once("modem_message", function(side, channel, replyChannel, message, distance)
        print(("Message received on side %s on channel %d (reply to %d) from %f blocks away with message %s"):format(
            side, channel, replyChannel, distance, tostring(message)
        ))
    end)
end
```

### off(event: string, func: function)
Removes an event listener. It removes the event listener that matches the given event and callback function. If there are multiple event listeners that match, it removes only the first one.

**Parameters**
- event: string: The event to listen for.
- func: function: The callback function to run when the event is fired.

**Outputs**

**Example**
```lua
local function cb(side, channel, replyChannel, message, distance)
    print(("Message received on side %s on channel %d (reply to %d) from %f blocks away with message %s"):format(
        side, channel, replyChannel, distance, tostring(message)
    ))
end

local function main()
    sys:on("modem_message", cb)
    sys:off("modem_message", cb) -- This will remove the event listener before it can be fired
end
```

### call(event: string, ...)
Executes the callback functions of the event listeners that match the given event. It executes the callback functions in the order they were registered. The callback functions run independently of the main task. See [on](#onevent-string-func-function)

**Parameters**
- event: string: The event to listen for.
- ...: any: The arguments to pass to the callback functions.

**Outputs**

**Example**
```lua
local function main()
    sys:on("custom_event", function(arg1, arg2)
        print("Custom event fired with arguments: ", arg1, arg2)
    end)
    sys:call("custom_event", "Hello,", "world!")
end
```

### start(func: function)
Starts the main loop. The function passed to this function will be the main task. If the main task finishes, an error is thrown.
**Parameters**
- func: function: The function to execute as the main task.

**Outputs**

**Example**
```lua
local function main()
    -- Your code here
end

sys:start(main)
```