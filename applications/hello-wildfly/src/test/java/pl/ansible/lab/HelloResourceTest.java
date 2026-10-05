package pl.ansible.lab;

import org.junit.jupiter.api.Test;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.junit.jupiter.api.extension.ExtendWith;
import pl.ansible.lab.dto.AppDataCreateDto;
import pl.ansible.lab.dto.AppDataDto;

import jakarta.ws.rs.NotFoundException;

import java.time.OffsetDateTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class HelloResourceTest {

    @Mock
    private GreetingService greetingService;

    @Mock
    private AppDataService appDataService;

    @InjectMocks
    private HelloResource helloResource;

    @Test
    void dataShouldReturnListFromService() {
        AppDataDto dto = new AppDataDto(
                1L,
                "test-host",
                OffsetDateTime.parse("2026-10-05T14:00:00+02:00")
        );

        when(appDataService.findAll())
                .thenReturn(List.of(dto));

        List<AppDataDto> result = helloResource.data();

        assertEquals(1, result.size());
        assertEquals("test-host", result.get(0).getHostname());
        verify(appDataService).findAll();
    }

    @Test
    void createDataShouldReturnDtoFromService() {
        AppDataDto dto = new AppDataDto(
                2L,
                "create-host",
                OffsetDateTime.parse("2026-10-05T14:00:00+02:00")
        );

        when(appDataService.create("create-host"))
                .thenReturn(dto);

        AppDataDto result =
                helloResource.createData("create-host");

        assertEquals(dto, result);
        verify(appDataService).create("create-host");
    }

    @Test
    void getDataShouldReturnDtoWhenEntityExists() {
        AppDataDto dto = new AppDataDto(
                5L,
                "test-host",
                OffsetDateTime.parse("2026-10-05T14:00:00+02:00")
        );

        when(appDataService.findById(5L))
                .thenReturn(dto);

        AppDataDto result =
                helloResource.getData(5L);

        assertEquals(dto, result);
        verify(appDataService).findById(5L);
    }

    @Test
    void getDataShouldThrowNotFoundWhenEntityDoesNotExist() {
        when(appDataService.findById(999L))
                .thenReturn(null);

        assertThrows(
                NotFoundException.class,
                () -> helloResource.getData(999L)
        );

        verify(appDataService).findById(999L);
    }

    @Test
    void updateDataShouldReturnDtoFromService() {
        AppDataCreateDto request = new AppDataCreateDto();
        request.setHostname("updated-host");

        AppDataDto dto = new AppDataDto(
                5L,
                "updated-host",
                OffsetDateTime.parse("2026-10-05T14:00:00+02:00")
        );

        when(appDataService.update(5L, "updated-host"))
                .thenReturn(dto);

        AppDataDto result =
                helloResource.updateData(5L, request);

        assertEquals(dto, result);
        verify(appDataService).update(5L, "updated-host");
    }

    @Test
    void updateDataShouldThrowNotFoundWhenEntityDoesNotExist() {
        AppDataCreateDto request = new AppDataCreateDto();
        request.setHostname("missing-host");

        when(appDataService.update(999L, "missing-host"))
                .thenReturn(null);

        assertThrows(
                NotFoundException.class,
                () -> helloResource.updateData(999L, request)
        );

        verify(appDataService).update(999L, "missing-host");
    }

    @Test
    void deleteDataShouldCallService() {
        when(appDataService.delete(5L))
                .thenReturn(true);

        helloResource.deleteData(5L);

        verify(appDataService).delete(5L);
    }

    @Test
    void deleteDataShouldThrowNotFoundWhenEntityDoesNotExist() {
        when(appDataService.delete(999L))
                .thenReturn(false);

        assertThrows(
                NotFoundException.class,
                () -> helloResource.deleteData(999L)
        );

        verify(appDataService).delete(999L);
    }
}
