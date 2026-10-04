package pl.ansible.lab;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.io.PrintWriter;

@WebServlet("/hello")
public class HelloServlet extends HttpServlet {

    @Override
    protected void doGet(
            HttpServletRequest request,
            HttpServletResponse response)
            throws ServletException, IOException {

        response.setContentType("text/html; charset=UTF-8");

        PrintWriter out = response.getWriter();

        out.println("""
                <!DOCTYPE html>
                <html>
                <head>
                    <meta charset="UTF-8">
                    <title>Hello Tomcat</title>
                </head>
                <body>
                    <h1>Hello from Jakarta Servlet!</h1>
                    <p>Application server: Apache Tomcat 11</p>
                    <p>Application: hello-tomcat</p>
                    <p>Java: 21</p>
                </body>
                </html>
                """);
    }
}
