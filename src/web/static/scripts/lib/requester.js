define(["constants"], function(c){
    let requesterObj = {
        get: function(url, params){
            return requesterObj.request("GET", url, params);
        },
        post: function(url, params){
            return requesterObj.request("POST", url, params);
        },
        patch: function(url, params){
            return requesterObj.request("PATCH", url, params);
        },
        delete: function(url, params){
            return requesterObj.request("DELETE", url, params);
        },
        put: function(url, params){
            return requesterObj.request("PUT", url, params);
        },
        request: function (method, url, params) {
            httpRequest = new XMLHttpRequest();
            let promise = new Promise(function (resolve, reject) {
                if (!httpRequest) {
                    console.error('REQUESTER_INVALID: Cannot create an XMLHTTP instance');
                    reject({
                        error: "REQUESTER_INVALID",
                        message: "Cannot create an XMLHTTP instance",
                        code: 2
                    });
                }
                else {
                    httpRequest.onreadystatechange = function () {
                        if (httpRequest.readyState === XMLHttpRequest.OPENED) {
                            if (params.headers) {
                                for (let header in params.headers) {
                                    httpRequest.setRequestHeader(header, params.headers[header]);
                                }
                            }
                            if (params.authorize) {
                                httpRequest.setRequestHeader("Authorization", "Bearer " + c.accessToken);
                            }
                        }
                        if (httpRequest.readyState === XMLHttpRequest.DONE) {
                            if (httpRequest.status === 200) {
                                if (httpRequest.responseType === "json") {
                                    try {
                                        let jsonData = httpRequest.response;
                                        resolve({
                                            data: jsonData,
                                            error: undefined,
                                            message: undefined,
                                            code: 1
                                        });
                                    }
                                    catch (e) {
                                        console.warn(e);
                                    }
                                }
                                else {
                                    console.log("Data returned, resolving...");
                                    resolve({
                                        data: httpRequest.responseText,
                                        error: undefined,
                                        message: undefined,
                                        code: 1
                                    });
                                }
                            }
                            else if (httpRequest.status === 204) {
                                resolve({
                                    data: {},
                                    error: undefined,
                                    message: undefined,
                                    code: 1
                                });
                            } else {
                                reject({
                                    error: "REQUESTER_INVALID_REQUEST",
                                    message: "A problem occurred with this request",
                                    code: 3
                                });
                            }
                        }
                    };
                    if (params.dataType){
                        switch(params.dataType){
                            case "json":
                                httpRequest.responseType = "json";
                                break;
                            case "html":
                                httpRequest.responseType = "text";
                                break;
                        }
                    }
                    httpRequest.open(method, url);
                    if (params.data){
                        httpRequest.send(JSON.stringify(params.data));
                    }
                    else{
                        httpRequest.send();
                    }
                }
            });
            return promise;
        }
    }
    return requesterObj;
});