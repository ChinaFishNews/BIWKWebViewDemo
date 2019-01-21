function ocCallJsNoParamsFunction()
{
    alert("OC调用JS中的无参方法");
}

function ocCallJsHasParamsFunction(name, url)
{
    alert(name+"的echo博客地址为："+url);
    var e = document.getElementById("js_shouw_text");
    e.options.add(new Option("OC调用JS中的有参方法", 2));
}
