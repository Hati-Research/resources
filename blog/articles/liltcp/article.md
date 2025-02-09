---
title: Explaining embedded Rust - liltcp
date: 2.2.2025
author: Matous Hybl
keywords: blog,embedded,rust,smoltcp
---
Recently, I've been doing consulting for a company, where they didn't want to use embassy, because they deemed it too difficult to navigate and understand (and due to a bad experience with one project based on it).
They wanted to leave the async embedded world altogether, but luckily they found [lilos](http://github.com/cbiffle/lilos) a really simple and straightforward async executor, which they embraced fully.

But since they were avoiding embassy altogether, they needed a TCP stack and that is when liltcp came to life. liltcp is a toy networking stack, but mainly a tutorial on writing async glue between smoltcp and a HAL (in this case stm32h7xx-hal).

Apart from the code in the [repo](http://github.com/hatiresearch/intrusive-thoughts), there is also a long form documentation that can be found [here](http://intrusive.hatiresearch.eu/liltcp.html). The tutorial goes from hardware bringup to having a fully async TCP Client, with detailed code explanation.

liltcp is part of HatiResearch's long term effort of making embedded Rust easier to understand and more approachable. This effort is called **Intrusive Thoughts** and liltcp is the first larger project done as part of it.

Happy hacking and let me know if you have any feedback.