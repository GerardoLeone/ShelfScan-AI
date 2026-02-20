package com.shelfscanai.controller;

import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class DevTestController {

    @GetMapping(value = "/scan-test", produces = MediaType.TEXT_HTML_VALUE)
    @ResponseBody
    public String scanTest() {
        return """
        <!doctype html>
        <html>
        <body>
          <h3>Scan test</h3>
          <form action="/api/scan" method="post" enctype="multipart/form-data">
            <div><input type="file" name="image" accept="image/*" required></div>
            <div><input type="text" name="title" placeholder="title"></div>
            <div><input type="text" name="author" placeholder="author"></div>
            <button type="submit">Upload</button>
          </form>
        </body>
        </html>
        """;
    }
}
