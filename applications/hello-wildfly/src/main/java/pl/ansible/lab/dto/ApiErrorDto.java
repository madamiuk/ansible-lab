package pl.ansible.lab.dto;

public class ApiErrorDto {

    private String error;
    private String message;

    public ApiErrorDto() {
    }

    public ApiErrorDto(String error, String message) {
        this.error = error;
        this.message = message;
    }

    public String getError() {
        return error;
    }

    public String getMessage() {
        return message;
    }
}
