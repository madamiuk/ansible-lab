package pl.ansible.lab;

import jakarta.ws.rs.NotFoundException;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.ext.ExceptionMapper;
import jakarta.ws.rs.ext.Provider;
import pl.ansible.lab.dto.ApiErrorDto;

@Provider
public class NotFoundExceptionMapper
        implements ExceptionMapper<NotFoundException> {

    @Override
    public Response toResponse(NotFoundException exception) {
        ApiErrorDto error = new ApiErrorDto(
                "Not Found",
                exception.getMessage()
        );

        return Response
                .status(Response.Status.NOT_FOUND)
                .type(MediaType.APPLICATION_JSON)
                .entity(error)
                .build();
    }
}
