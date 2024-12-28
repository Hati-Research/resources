---
title: Introduction to Full^2 stack - web development
date: 28.12.2024
author: Matous Hybl
keywords: rust, axum, htmx, hypertext
---
Web development was always the missing part in Hati Research.
While doing some basic HTML and CSS was never a problem (and even more complex things with some quick prompting), doing more dynamic web pages always seemed scary, especially given the current state of the ecosystem and the resulting decision paralysis coming from it.

Fortunately, thanks to an influencer who used to work at Netflix, btw, I discovered HTMX and a whole new world was suddenly open for us. HTMX is extremely light-weight JS library (not a framework) that does mainly two things:

1. adds the ability to call GET, POST, PUT, PATCH and DELETE endpoints from all clickable elements.
2. adds mechanisms to replace parts of the DOM with HTML responses of these endpoint calls.

Wait, this sounds like server-side rendering! Yes, it is, but with the twist is that you are able to introduce granular reactivity via replacing small parts of the DOM with the responses.
This is in stark contrast to the reactivity-first react-like SPA approach, where reactivity is a feature that everything is built upon.
In my opinion the SSR approach with granular reactivity leads to easier to develop robust prototypes, since the code can be written in memory safe languages.
Also since Rust is being used throughout the entire stack, some code can even be reused between components - good luck sharing code between Rust and React, unless you use WASM.

So, when developing a web app as part of the whole solution, the stack looks like the following:

* Tokio - asynchronous programming and executor
* Axum - HTTP framework
* Hypertext - inline, type checked and composable HTML components
* TailwindCSS - inline CSS definitions for avoiding write-only CSS stylesheets

Quick note on using templates - while templates certainly solve the problems of rendering dynamic HTML, the developer experience of using them is certainly not great, mostly because of having to do wrangling of another type of files with custom syntax for interpolations.
In general, this is a clash of the Separation of Concerns and Locality of Behavior principles, where I strongly believe that the second one is better, especially for prototypes.

### Sample app
Let's now dive into a simple application based on the described stack.
The app will consist of a text for displaying a counter value and a button for incrementing the value.

#### Adding support for HTMX attributes to hypertext
By default, hypertext doesn't support HTMX attributes, but adding them is quick and painless.

```rust
#[allow(unused, non_upper_case_globals)]
trait HtmxAttributes {
    // core
    const hx_get: Attribute = Attribute;
    const hx_post: Attribute = Attribute;
    // WARN: not supported by the hypertext crate
    const hx_on: Attribute = Attribute;
    const hx_push_url: Attribute = Attribute;
    const hx_select: Attribute = Attribute;
    const hx_select_oob: Attribute = Attribute;
    const hx_swap: Attribute = Attribute;
    const hx_swap_oob: Attribute = Attribute;
    const hx_target: Attribute = Attribute;
    const hx_trigger: Attribute = Attribute;
    const hx_vals: Attribute = Attribute;
    // additional
    const hx_boost: Attribute = Attribute;
    const hx_confirm: Attribute = Attribute;
    const hx_delete: Attribute = Attribute;
    const hx_disable: Attribute = Attribute;
    const hx_disable_elt: Attribute = Attribute;
    const hx_disinherit: Attribute = Attribute;
    const hx_encoding: Attribute = Attribute;
    const hx_ext: Attribute = Attribute;
    const hx_headers: Attribute = Attribute;
    const hx_history: Attribute = Attribute;
    const hx_history_elt: Attribute = Attribute;
    const hx_include: Attribute = Attribute;
    const hx_indicator: Attribute = Attribute;
    const hx_params: Attribute = Attribute;
    const hx_patch: Attribute = Attribute;
    const hx_preserve: Attribute = Attribute;
    const hx_prompt: Attribute = Attribute;
    const hx_put: Attribute = Attribute;
    const hx_replace_url: Attribute = Attribute;
    const hx_request: Attribute = Attribute;
    const hx_sync: Attribute = Attribute;
    const hx_validate: Attribute = Attribute;
}

impl<T> HtmxAttributes for T where T: GlobalAttributes {}
```

#### Defining the application state and setting up the router
The state of the app consists only of one `Arc`ed `AtomicUsize`.

```rust
#[derive(Clone)]
struct AppState {
    counter: Arc<AtomicUsize>,
}
```

Let's then set-up the router with the state and definitions of all of the routes:

```rust
#[tokio::main]
async fn main() {
    let router = Router::new()
        .route("/", get(index))
        .route("/clicked", post(clicked))
        .with_state(AppState {
            counter: Arc::new(AtomicUsize::new(0)),
        });

    let listener = TcpListener::bind("::0:8000").await.unwrap();
    let _ = axum::serve(listener, router).await;
}
```

Nothing interesting to see here, just a plain Axum application.

#### Implementing the endpoints
Let's start with the `/` endpoint.
This endpoint should return the HTML of the whole page.
```rust
async fn index(State(s): State<AppState>) -> impl IntoResponse {
    let click_count = s.counter.load(Ordering::SeqCst);
    rsx! {
        <html>
            <head>
              <script src="https://unpkg.com/htmx.org@2.0.4"></script>
            </head>
            <body>
                {counter(click_count)}
                <button hx-post="/clicked" hx-target="#counter">Click Me!</button>
            </body>
        </html>
    }
    .render()
}
```
Apart from the base HTML structure, the macro for the index definition includes a `counter` component and then defines a button for incrementing the state.
Notice the used HTMX attributes - there is `hx-post="/clicked"` meaning that a click will call POST on the `/clicked` endpoint and `hx-target="#counter"` which sets that the HTML returned from the POST will replace the element with the `id` `#counter`. There are several ways of replacing the DOM parts (e.g. replacing inner elements, outer, etc), which can be controlled with the attribute `hx-swap`.

In the following snippet, you can see the `counter` component.
```rust
fn counter(count: usize) -> impl Renderable {
    rsx_move! {
        <div id="counter">
            {format!("Clicked: {count}")}
        </div>
    }
}
```
While this code certainly could have been repeated in both of the endpoints, it is better to extract is as a component for easier maintainability (and upholding the DRY principle).

As for the clicked endpoint, it looks similar:
```rust
async fn clicked(State(state): State<AppState>) -> impl IntoResponse {
    let _ = state.counter.fetch_add(1, Ordering::SeqCst);
    let click_count = state.counter.load(Ordering::SeqCst);

    counter(click_count).render()
}
```
Here, the code only increments the counter and returns the rendered `counter` component.

#### Styling
Adding styling via TailwindCSS is a bit more elaborate as it requires calling the external TailwindCSS compiler.
Fortunately, Cargo has a mechanism for developing build scripts built-in, so let's utilize that:
```rust
use std::{error::Error, process::Command};

fn main() -> Result<(), Box<dyn Error>> {
    println!("rustc:rerun-if-changed=resources/tailwind.css");
    // TODO: In real program, change to a directory containing your html component definitions
    println!("rustc:rerun-if-changed=src/**/*.rs");
    let output = Command::new("npx")
        .arg("tailwindcss")
        .arg("-i")
        .arg("resources/tailwind.css")
        .arg("-o")
        .arg("static/stylesheet.css")
        .output()?;
    if !output.status.success() {
        panic!(
            "TailwindCSS compiler failed with exit code: {} and stderr: {}",
            output.status.code().unwrap_or(-1),
            String::from_utf8(output.stderr)?
        );
    }
    Ok(())
}
```
_build.rs_

Cargo will automatically run this build script every time Tailwind's configuration CSS changes and every time any Rust file changes.
To avoid pointless rebuilding, the directive should instead of all Rust files match only files that contain HTML components.

Next, we need to instruct Axum to serve a directory with the compiled CSS.
There are several options for doing this, I used `tower_http`'s `ServeDir` service.
```rust
let router = Router::new()
	.route("/", get(index))
	.route("/clicked", post(clicked))
	.with_state(AppState {
		counter: Arc::new(AtomicUsize::new(0)),
	})
	.nest_service("/static", ServeDir::new("static"));
```
_main.rs_

Now, Axum will automatically serve any file stored in the `static` directory under the resource path `/static`.

Finally, we can include our stylesheet in the index component:
```rust
<link rel="stylesheet" href="/static/stylesheet.css">
```

And the only thing left to do is to add Tailwind's utility classes to our code, for example to make the counter text red.
```rust
fn counter(count: usize) -> impl Renderable {
    rsx_move! {
        <div class="text-red-500" id="counter">
            {format!("Clicked: {count}")}
        </div>
    }
}
```

### To wrap up...
This is all there is to it. We have a reactive application written in Rust, which runs on the server and uses minimal amount of data for transfers - no transferring hundreds of KB of minified JS.

The complete project can be found on [Github](https://github.com/Hati-Research/full2stack-web-showcase).