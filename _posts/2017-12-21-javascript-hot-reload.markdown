---
layout: post
title:  "关于JavaScript的动态加载 —— 1、在服务器端，我们能做到什么"
date:   2017-12-21 19:38:50 +0800
categories: JavaScript Essay
---

# 关于JavaScript的动态加载 —— 1、在服务器端，我们能做到什么

## 1、说在前面

本文是一系列讨论动态加载（JavaScript）技术的文章的第一篇。主要讨论的是在服务器端，使用JavaScript，我们能做到什么，并且，这么做，会带来什么样的好处。

本文会讨论到的技术有：

1. [NodeJS](http://nodejs.org)
2. [ES6](https://www.ecma-international.org/ecma-262/6.0/)
3. [Proxy](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Proxy)
4. [ExpressJS](http://expressjs.com)

本文不是关于这几个技术的科普文章，所以，如果你对上面我提到的这几个技术并不是很了解，建议你先从看一下相关的内容（比如我上面列的链接）开始。这样可以有效的节约你我的时间。

## 2、先说问题

JavaScript本身就是一个动态的语言，它的动态性包括了下面几个特征：

1. 它是解释执行的（虽然可以有[JIT](http://thibaultlaurens.github.io/javascript/2013/04/29/how-the-v8-engine-works/)的支持），所以，它运行的代码是可以在运行时加载甚至是改变的
2. 它是弱类型的，所以，你定义的变量，它可以在运行时任意的被改变，只要满足[Duck Typing](https://en.wikipedia.org/wiki/Duck_typing)，API级别的兼容是非常容易的
3. 对于它本身来说，任何的对象都不是Sealed，所以，你可以在运行的时候，随便的修改对象的属性和方法，甚至在调用的时候主动的改变方法的`this`对象

所以，对于JavaScript来说，它本身应该是没有什么动态性的问题的。那么，我们说的动态加载的问题是什么呢？

下面，我会列几个常见的场景来举例。

## 2.1、最常见的Express开发范式

任何一个用Express开发过项目的人都会遇到过同样的问题。

1. 新建一个Router（怎么样随便你）
2. 把这个Router加入到总的Router文件中（或者你总的Router文件使用文件夹轮循也行，这个不影响）

然后呢？你会发现，你需要重启Express。

为什么？因为你的Express只有在启动的时候才会初始化Routing的部分。

于是你搞了一个[nodemon](https://github.com/remy/nodemon)来监听你的代码修改。任何代码修改，都会重启Express，完美！

Wait！Express停了，重启，Session怎么办？于是你又需要在本地搞一个MongoDB，来保存Session，才能保证Session会在你重启Express的时候有所保留。

问题是，你只是想要改一个（或者加一个）Routing里面的内容，需要这么大费周章么？JavaScript不是动态的么？我们上面不是说过了它其实是可以支持动态化的么？

## 2.2、很常见的应用调试方式

假设你开发了一个小的NodeJS应用，去提供一个简单的HTTP服务。你在程序运行的时候，Client遇到了一个小问题，你想要看一下此时的输出是什么。

当然，你可以在开始的时候就用Logging支持来把Debug加上去（修改Logging配置也需要重启）。

或者，你可以用Inspect模式来启动应用，然后加断点进入调试。

问题是你可能只是想要加一个log，或者console的输出而已，你就需要把整个应用关掉，再重新启动。JavaScript不是动态的么？我们上面不是说过了它其实是可以支持动态化的么？

## 3、了解问题

刚刚据说的问题，其实归根结底就是两个目前JavaScript开发和框架里面最常见的问题：

1. 虽然JavaScript本身对动态的支持是足够的，但是使用它的框架本身并没有充分的利用这一点
2. JavaScript里面的变量机制其实还是从C一脉相承的，变量引用机制本身动态化并不是很好，除非你非常强烈的使用函数式编程，不然，其实你的代码的动态性是很差的。

我随便举一个例子：


{% highlight javascript %}

const { hello, world } = require("utils");

setInterval(() => hello(world()), 1000);

{% endhighlight %}

这个例子是一个很明显和简单的例子。第一行是在`utils`包中加载`hello`和`world`两个函数。第二行是建立一个匿名函数，每隔一秒钟执行一下`world`函数，并把运行结果输出给`hello`函数。

很明显，只要程序本身不退出的话。`hello`和`world`函数会每秒调用一次。

但是，这时，你如果改变了`utils`模块的代码里面`hello`和`world`的实现了呢？会出现什么情况？

1. 因为`require`函数并没有再被调用，所以，`hello`和`world`函数在你运行的NodeJS实例里面并不会发生改变，虽然实现它们的代码其实已然改变了
2. 就算是你把`require`函数加到里面，变成这样

{% highlight javascript %}
setInterval(() => { let {hello, world} = require("utils"); hello(world());}, 1000)
{% endhighlight %}

你也会发现，并没有任何效果。为什么呢？因为NodeJS的`require`会在全局建立一个模块缓存，你加载过的模块，不会再去它的源文件中加载一遍，而是直接把缓存中的模块实现给到你。这就意味着，你想要实现动态加载，需要的是这样：

{% highlight javascript %}
setInterval( () => {
	purgeModuleCache("utils");
	let {hello, world} = require("utils");
	hello(world());
}, 1000)
{% endhighlight %}

其中`purgeMoudleCache`是一个比较有趣的方法（当然是需要自己实现的，具体实现方式可以参考我写的[hot-pepper-jelly](http://github.com/guitarpoet/hot-pepper-jelly)）

但是，我们来对比一下，之前的代码：

{% highlight javascript %}
setInterval(() => hello(world()), 1000);
{% endhighlight %}

已经差得不是一点半点了。而且，还需要对代码有非常强的侵入性，而且还会带来性能问题（每次都加载一遍，当然会有性能问题。。。。）。

那么，这个问题该如何解决呢？

## 4、解决方案

其实这个问题的解决方式，[Java](https://java.com/en/)早在十几年前，就已经在[J2EE](http://www.oracle.com/technetwork/java/javaee/appmodel-135059.html)中做了一个很好的示范了（对的，例子就是那个背了多年恶名的[EJB](https://en.wikipedia.org/wiki/Enterprise_JavaBeans)）。

随便举一个使用EJB的代码的例子：


{% highlight java %}
// Let's construct the context first
Context ctx = new InitialContext();

HelloHome helloHome =  javax.rmi.PortableRemoteObject.narrow(ctx.lookup(THE_PATH_TO_HELLO_HOME),
	HelloHome.class);
	
Hello hello = helloHome.create();

new Thread(() -> {
	while(true) {
		try {
			hello.world();
			Thread.sleep(10);
		} catch(Exception ex) {
			ex.printStacktrace();
		}
	}
}).start();
{% endhighlight %}


同样的代码。这里面的Hello是一个EJB，它是怎么得到的就太复杂先不说了，说结果。当Hello这个EJB发生了改变的时候（就是重新布署了之后）。

这段代码仍然可以正常运行，并且，会把Hello这个EJB最新的代码实现的功能使用起来。它是怎么实现的呢？

## 4.1、通过Proxy实现不变引用的前提下，改变实现

使用Proxy，来实现动态特性，是动态化里面一个很常用的方式。EJB就是使用的这种方式。

在上面的例子里面，Hello其实是一个Interface。它的实现是HelloBean，但是，你在运行时拿到的并不是HelloBean。

说得再浅显一些，就是：

{% highlight java %}
Hello hello = new HelloBean();
{% endhighlight %}

如果你是这样获得到的Hello对象的实现，那么如果HelloBean的实现发生了改变，你必须需要重新加载这段代码。不然，像Java这种强类型的语言，你的程序会直接出问题。

但是，如果你是通过一个容器得到的Hello这个Interface的实现，就不一样了。你得到的只是一个实现了Hello这个Interface的动态Proxy对象。

关于动态Proxy对象是什么， 它是怎么个实现，请看[这里](http://www.baeldung.com/java-dynamic-proxies)。

这点在ES6之前，JavaScript中是没有的。这也是为什么现在并没有什么框架支持这一点的主要原因。。。。。因为很多人根本从来就没用过这种方式。而这种方式目前版本的NodeJS（NodeJS 8）已经完美支持了。

## 4.2、充分利用JavaScript本身的动态加载能力，在运行时替换实现

在JavaScript里面，你根本不需要一个容器，因为NodeJS就是你的一个容器。

你也不需要安装布署什么模块（像EJB那么麻烦），因为对于NodeJS来说，NODE_PATH就是你的模块路径。JS文件就是你的模块。一个`require`方法就可以实现模块的加载。非常方便。

所以，只要使用Proxy把NodeJS加载的内容包装一下。就可以了。

## 4.3、全局的Proxy注册机制

拿一个示例代码来说明：

{% highlight javascript %}
const { load } = require("hot-pepper-jelly");
const { hello, world} = load("utils");

setInterval(() => hello(world()), 1000);
{% endhighlight %}

在这段代码里面。`hello`和`world`都是使用hot-pepper-jelly加载并且托管的。你拿到的引用`hello`和`world`其实只是一个假装自己是`hello`和`world`方法的Proxy。

它真正的功能，是把加载后的模块，放到一个全局的模块注册表中。每次调用它们的时候，它们会在这个注册表中查找它对应的模块，并且让它们的实现来真正提供需要的服务。

因为中间多了这么一个全局注册表的机制。你就完全可以在另一个线程里面，对这个注册表进行你想要的修改。比如，监听文件的修改，然后把该文件的最新的模块，注册到全局的注册表中。

这样，下一时间`hello`或者`world`函数在调用的时候， 就会使用最新的实现来处理了。而无需做任何重启操作。

## 4.4、示例代码

{% highlight javascript %}
const express = require("express");
const { enable_hotload, load, pipe } = require("hot-pepper-jelly");
const init = require("./initializer.js");
const run = require("./starter");
const path = require("path");

enable_hotload(); // Let's enable the hot reload feature

const error_report = console.error;
const setup_router = (app) => {
    app.use("/", load("./router"));
    return app;
}

pipe(express())(init, setup_router, run).
    then((app) => console.info("Done")).catch(error_report);

{% endhighlight %}

关于其中的Pipe，就是另外一个话题了。

## What Next？

下一步，我会把hot-pepper-jelly这个项目简要的介绍一下，并且把里面我用到的一些有趣的东西和概念一一详细说明。

本系列的后面部分，还会有关于前端JS的一些想法，这也是hot-pepper-jelly这个项目的最终目标。就是无论前端还是后端，都可以使用到最方便和灵活并且安全的动态加载技术（在DEV模式下）。

以及，最重要的一部分，如何在浏览器兼容的方式下实现更完美的动态加载。。。。
