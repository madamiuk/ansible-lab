package pl.ansible.lab;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import javax.naming.InitialContext;
import javax.sql.DataSource;

import java.io.IOException;
import java.io.PrintWriter;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

@WebServlet("/hello")
public class HelloServlet extends HttpServlet {

    private DataSource dataSource;

    @Override
    public void init() throws ServletException {
        try {
            InitialContext context = new InitialContext();
            dataSource = (DataSource) context.lookup(
                    "java:comp/env/jdbc/ansibleLab");
        } catch (Exception e) {
            throw new ServletException(
                    "Nie można odnaleźć JNDI DataSource", e);
        }
    }

    @Override
    protected void doGet(
            HttpServletRequest request,
            HttpServletResponse response)
            throws ServletException, IOException {

        response.setContentType("text/html; charset=UTF-8");

        try (Connection connection = dataSource.getConnection();
             PreparedStatement statement = connection.prepareStatement("""
                     SELECT id, hostname, created_at
                     FROM app_data
                     ORDER BY id
                     """);
             ResultSet resultSet = statement.executeQuery();
             PrintWriter out = response.getWriter()) {

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

                        <h2>PostgreSQL</h2>
                        <table border="1">
                            <tr>
                                <th>ID</th>
                                <th>Hostname</th>
                                <th>Created at</th>
                            </tr>
                    """);

            while (resultSet.next()) {
                out.printf(
                        """
                            <tr>
                                <td>%d</td>
                                <td>%s</td>
                                <td>%s</td>
                            </tr>
                        """,
                        resultSet.getLong("id"),
                        resultSet.getString("hostname"),
                        resultSet.getTimestamp("created_at"));
            }

            out.println("""
                        </table>
                    </body>
                    </html>
                    """);

        } catch (SQLException e) {
            throw new ServletException(
                    "Błąd podczas odczytu danych PostgreSQL", e);
        }
    }
}
